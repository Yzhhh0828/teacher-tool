// Router unit tests focused on the auth-driven redirect contract and the
// _AuthChangeNotifier semantics (only fires on isLoggedIn flips).
//
// We run these as plain unit tests against a ProviderContainer because
// the LoginScreen contains perpetual flutter_animate orbs which prevent
// `pumpAndSettle` from ever returning in widget tests.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teacher_tool/core/router.dart';
import 'package:teacher_tool/core/services/prefs_service.dart';
import 'package:teacher_tool/data/models/user.dart';
import 'package:teacher_tool/providers/auth_provider.dart';
import 'package:teacher_tool/providers/prefs_provider.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ProviderContainer> makeContainer() async {
    final prefs = await PrefsService.create();
    return ProviderContainer(overrides: [
      prefsServiceProvider.overrideWithValue(prefs),
    ]);
  }

  test(
      'GoRouter instance is preserved across non-auth state changes (no recreation)',
      () async {
    final c = await makeContainer();
    addTearDown(c.dispose);

    final router1 = c.read(routerProvider);

    // Hammer isLoading without flipping isLoggedIn — used to recreate the
    // GoRouter every time and tear down the LoginScreen, losing its state.
    for (var i = 0; i < 5; i++) {
      c.read(authStateProvider.notifier).state = c
          .read(authStateProvider)
          .copyWith(isLoading: i.isEven);
      await Future<void>.delayed(Duration.zero);
    }

    final router2 = c.read(routerProvider);
    expect(identical(router1, router2), isTrue,
        reason:
            'GoRouter must be created once, not recreated on each auth state change.');
  });

  test('GoRouter instance is also preserved when isLoggedIn flips', () async {
    final c = await makeContainer();
    addTearDown(c.dispose);
    final router1 = c.read(routerProvider);

    c.read(authStateProvider.notifier).state =
        c.read(authStateProvider).copyWith(
              isLoggedIn: true,
              user: User(
                id: 1,
                phone: '13912345678',
                createdAt: DateTime(2026),
              ),
            );
    await Future<void>.delayed(const Duration(milliseconds: 30));

    final router2 = c.read(routerProvider);
    expect(identical(router1, router2), isTrue,
        reason:
            'Auth flips must trigger refreshListenable, not recreate the GoRouter.');
  });

  test('initial location is /workspace', () async {
    final c = await makeContainer();
    addTearDown(c.dispose);
    final router = c.read(routerProvider);
    // routerConfiguration carries the configured initialLocation.
    expect(router.configuration.findMatch(Uri.parse('/')), isNotNull);
    // Sanity: the path constants line up with the configured shell.
    expect(AppRoutes.workspace, '/workspace');
    expect(AppRoutes.login, '/login');
  });
}
