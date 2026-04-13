import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/api_client.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/models/user.dart';

const _authStateUnset = Object();
enum SessionEvent { sessionExpired }

final sessionEventsProvider = Provider<StreamController<SessionEvent>>((ref) {
  final controller = StreamController<SessionEvent>.broadcast();
  ref.onDispose(controller.close);
  return controller;
});

final apiClientProvider = Provider((ref) {
  final sessionEvents = ref.read(sessionEventsProvider);
  return ApiClient(
    onSessionExpired: () async {
      if (!sessionEvents.isClosed) {
        sessionEvents.add(SessionEvent.sessionExpired);
      }
    },
  );
});
final authRepositoryProvider = Provider((ref) => AuthRepository(ref.read(apiClientProvider)));

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.read(authRepositoryProvider),
    ref.read(sessionEventsProvider).stream,
  );
});

class AuthState {
  final bool isLoading;
  final bool isLoggedIn;
  final User? user;
  final String? error;
  final String? debugCode;

  AuthState({
    this.isLoading = false,
    this.isLoggedIn = false,
    this.user,
    this.error,
    this.debugCode,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isLoggedIn,
    Object? user = _authStateUnset,
    Object? error = _authStateUnset,
    Object? debugCode = _authStateUnset,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      user: identical(user, _authStateUnset) ? this.user : user as User?,
      error: identical(error, _authStateUnset) ? this.error : error as String?,
      debugCode: identical(debugCode, _authStateUnset)
          ? this.debugCode
          : debugCode as String?,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  late final StreamSubscription<SessionEvent> _sessionSubscription;

  AuthNotifier(this._repository, Stream<SessionEvent> sessionEvents)
      : super(AuthState(isLoading: true)) {
    _sessionSubscription = sessionEvents.listen((event) {
      if (event == SessionEvent.sessionExpired) {
        handleSessionExpired();
      }
    });
  }

  Future<void> checkLoginStatus() async {
    state = state.copyWith(isLoading: true);
    final isLoggedIn = await _repository.isLoggedIn();
    if (isLoggedIn) {
      try {
        final user = await _repository.getMe();
        state = state.copyWith(
          isLoading: false,
          isLoggedIn: true,
          user: user,
          error: null,
        );
      } catch (_) {
        state = state.copyWith(isLoading: false, isLoggedIn: false, user: null);
      }
    } else {
      state = state.copyWith(isLoading: false, isLoggedIn: false, user: null);
    }
  }

  Future<void> sendCode(String phone) async {
    state = state.copyWith(isLoading: true, error: null, debugCode: null);
    try {
      final debugCode = await _repository.sendCode(phone);
      state = state.copyWith(isLoading: false, debugCode: debugCode);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _normalizeError(e),
        debugCode: null,
      );
    }
  }

  Future<void> login(String phone, String code) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.login(phone, code);
      final user = await _repository.getMe();
      state = state.copyWith(
        isLoading: false,
        isLoggedIn: true,
        user: user,
        debugCode: null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _normalizeError(e));
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = AuthState();
  }

  void handleSessionExpired() {
    state = AuthState(error: '登录状态已失效，请重新登录');
  }

  @override
  void dispose() {
    _sessionSubscription.cancel();
    super.dispose();
  }

  String _normalizeError(Object error) {
    final message = error.toString();
    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }
    return message;
  }
}
