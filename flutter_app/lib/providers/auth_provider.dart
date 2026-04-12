import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/api_client.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/models/user.dart';

final apiClientProvider = Provider((ref) => ApiClient());
final authRepositoryProvider = Provider((ref) => AuthRepository(ref.read(apiClientProvider)));

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authRepositoryProvider));
});

class AuthState {
  final bool isLoading;
  final bool isLoggedIn;
  final User? user;
  final String? error;

  AuthState({
    this.isLoading = false,
    this.isLoggedIn = false,
    this.user,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isLoggedIn,
    User? user,
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      user: user ?? this.user,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(AuthState());

  Future<void> checkLoginStatus() async {
    state = state.copyWith(isLoading: true);
    final isLoggedIn = await _repository.isLoggedIn();
    if (isLoggedIn) {
      try {
        final user = await _repository.getMe();
        state = state.copyWith(isLoading: false, isLoggedIn: true, user: user);
      } catch (_) {
        state = state.copyWith(isLoading: false, isLoggedIn: false);
      }
    } else {
      state = state.copyWith(isLoading: false, isLoggedIn: false);
    }
  }

  Future<void> sendCode(String phone) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.sendCode(phone);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> login(String phone, String code) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.login(phone, code);
      final user = await _repository.getMe();
      state = state.copyWith(isLoading: false, isLoggedIn: true, user: user);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = AuthState();
  }
}
