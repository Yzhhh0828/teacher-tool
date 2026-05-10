import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teacher_tool/core/services/prefs_service.dart';
import 'package:teacher_tool/data/models/user.dart';
import 'package:teacher_tool/data/repositories/auth_repository.dart';
import 'package:teacher_tool/providers/auth_provider.dart';
import 'package:teacher_tool/providers/prefs_provider.dart';

class _MockAuthRepo extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepo repo;
  late StreamController<SessionEvent> sessionEvents;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = _MockAuthRepo();
    sessionEvents = StreamController<SessionEvent>.broadcast();
  });

  tearDown(() async {
    await sessionEvents.close();
  });

  Future<ProviderContainer> makeContainer({
    Map<String, Object> initialPrefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(initialPrefs);
    final prefs = await PrefsService.create();
    final controller = StreamController<SessionEvent>.broadcast();
    addTearDown(controller.close);
    return ProviderContainer(overrides: [
      prefsServiceProvider.overrideWithValue(prefs),
      authRepositoryProvider.overrideWithValue(repo),
      sessionEventsProvider.overrideWithValue(controller),
    ]);
  }

  test('initial state isLoading=true, not logged in', () async {
    final c = await makeContainer();
    addTearDown(c.dispose);
    final s = c.read(authStateProvider);
    expect(s.isLoading, isTrue);
    expect(s.isLoggedIn, isFalse);
    expect(s.user, isNull);
  });

  test('checkLoginStatus: no token → isLoggedIn=false', () async {
    when(() => repo.isLoggedIn()).thenAnswer((_) async => false);
    final c = await makeContainer();
    addTearDown(c.dispose);

    await c.read(authStateProvider.notifier).checkLoginStatus();

    final s = c.read(authStateProvider);
    expect(s.isLoading, isFalse);
    expect(s.isLoggedIn, isFalse);
    expect(s.user, isNull);
  });

  test('checkLoginStatus: token + getMe success → logged in', () async {
    when(() => repo.isLoggedIn()).thenAnswer((_) async => true);
    when(() => repo.getMe()).thenAnswer((_) async => User(
          id: 1,
          phone: '13912345678',
          createdAt: DateTime(2026),
        ));
    final c = await makeContainer();
    addTearDown(c.dispose);

    await c.read(authStateProvider.notifier).checkLoginStatus();
    final s = c.read(authStateProvider);
    expect(s.isLoggedIn, isTrue);
    expect(s.user?.phone, '13912345678');
  });

  test('checkLoginStatus: token but getMe throws → falls back to logged-out',
      () async {
    when(() => repo.isLoggedIn()).thenAnswer((_) async => true);
    when(() => repo.getMe()).thenThrow(Exception('expired'));
    final c = await makeContainer();
    addTearDown(c.dispose);

    await c.read(authStateProvider.notifier).checkLoginStatus();
    final s = c.read(authStateProvider);
    expect(s.isLoggedIn, isFalse);
    expect(s.user, isNull);
  });

  test('sendCode stores debugCode on success', () async {
    when(() => repo.sendCode(any())).thenAnswer((_) async => '123456');
    final c = await makeContainer();
    addTearDown(c.dispose);

    await c.read(authStateProvider.notifier).sendCode('13912345678');
    expect(c.read(authStateProvider).debugCode, '123456');
    expect(c.read(authStateProvider).error, isNull);
  });

  test('sendCode surfaces normalized error', () async {
    when(() => repo.sendCode(any())).thenThrow(Exception('rate limit'));
    final c = await makeContainer();
    addTearDown(c.dispose);

    await c.read(authStateProvider.notifier).sendCode('13912345678');
    expect(c.read(authStateProvider).error, contains('rate limit'));
    expect(c.read(authStateProvider).debugCode, isNull);
  });

  test('login wires getMe, flips isLoggedIn=true', () async {
    when(() => repo.login(any(), any())).thenAnswer(
        (_) async => AuthTokens(accessToken: 'a', refreshToken: 'r'));
    when(() => repo.getMe()).thenAnswer((_) async => User(
          id: 7,
          phone: '13912345678',
          createdAt: DateTime(2026),
        ));
    final c = await makeContainer();
    addTearDown(c.dispose);

    await c
        .read(authStateProvider.notifier)
        .login('13912345678', '123456');
    expect(c.read(authStateProvider).isLoggedIn, isTrue);
    expect(c.read(authStateProvider).user?.id, 7);
  });

  test('logout calls repo.logout and clears session prefs', () async {
    when(() => repo.logout()).thenAnswer((_) async {});
    final c = await makeContainer(initialPrefs: {
      'current_class_id': 5,
      'last_tab_path': '/students',
      'theme_palette': 'warmOrange',
    });
    addTearDown(c.dispose);
    expect(c.read(prefsServiceProvider).currentClassId, 5);

    await c.read(authStateProvider.notifier).logout();

    verify(() => repo.logout()).called(1);
    expect(c.read(authStateProvider).isLoggedIn, isFalse);
    expect(c.read(prefsServiceProvider).currentClassId, isNull);
    expect(c.read(prefsServiceProvider).lastTabPath, isNull);
    // Theme survives logout.
    expect(c.read(prefsServiceProvider).themePalette, 'warmOrange');
  });

  test('handleSessionExpired sets a friendly error and wipes prefs', () async {
    final c = await makeContainer(initialPrefs: {'current_class_id': 9});
    addTearDown(c.dispose);

    c.read(authStateProvider.notifier).handleSessionExpired();
    // Microtask drain to let the unawaited prefs cleanup land.
    await Future<void>.delayed(Duration.zero);

    final s = c.read(authStateProvider);
    expect(s.error, contains('登录'));
    expect(s.isLoggedIn, isFalse);
    expect(c.read(prefsServiceProvider).currentClassId, isNull);
  });
}
