import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../ui/screens/auth/login_screen.dart';
import '../ui/screens/grade/exam_list_screen.dart';
import '../ui/screens/home/home_screen.dart';
import '../ui/screens/presentation/presentation_screen.dart';
import '../ui/screens/schedule/schedule_screen.dart';
import '../ui/screens/seating/seating_screen.dart';
import '../ui/screens/behavior/behavior_screen.dart';
import '../ui/screens/settings/settings_screen.dart';
import '../ui/screens/student/student_list_screen.dart';
import '../ui/shell_scaffold.dart';
import '../agent/chat_screen.dart';
import '../ui/widgets/page_transitions.dart';

class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen<AuthState>(authStateProvider, (prev, next) {
      // Only refresh router when login status actually flips,
      // not on every loading/error/debugCode state change.
      if (prev?.isLoggedIn != next.isLoggedIn) {
        notifyListeners();
      }
    });
  }
}

/// Route path constants used throughout the app.
class AppRoutes {
  static const login = '/login';
  static const workspace = '/workspace';
  static const students = '/students';
  static const grades = '/grades';
  static const schedule = '/schedule';
  static const seating = '/seating';
  static const classroom = '/classroom';
  static const behavior = '/behavior';
  static const ai = '/ai';
  static const settings = '/settings';

  /// Ordered shell paths matching [ShellDestinations.items] indices.
  static const shellPaths = [
    workspace, // 0
    students, // 1
    grades, // 2
    schedule, // 3
    seating, // 4
    classroom, // 5
    behavior, // 6
    ai, // 7
    settings, // 8
  ];

  static int indexForLocation(String location) {
    for (var i = 0; i < shellPaths.length; i++) {
      if (location.startsWith(shellPaths[i])) return i;
    }
    return 0;
  }

  static String pathForIndex(int index) {
    return (index >= 0 && index < shellPaths.length)
        ? shellPaths[index]
        : workspace;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _AuthChangeNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.workspace,
    debugLogDiagnostics: false,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final isLoggedIn = ref.read(authStateProvider).isLoggedIn;
      final isLoggingIn = state.matchedLocation == AppRoutes.login;

      if (!isLoggedIn && !isLoggingIn) return AppRoutes.login;
      if (isLoggedIn && isLoggingIn) return AppRoutes.workspace;
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        redirect: (_, __) => AppRoutes.workspace,
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => ShellScaffold(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.workspace,
            pageBuilder: (context, state) => FadeThroughPage(
              key: state.pageKey,
              child: const HomeScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.students,
            pageBuilder: (context, state) => FadeThroughPage(
              key: state.pageKey,
              child: const StudentListScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.grades,
            pageBuilder: (context, state) => FadeThroughPage(
              key: state.pageKey,
              child: const ExamListScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.schedule,
            pageBuilder: (context, state) => FadeThroughPage(
              key: state.pageKey,
              child: const ScheduleScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.seating,
            pageBuilder: (context, state) => FadeThroughPage(
              key: state.pageKey,
              child: const SeatingScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.classroom,
            pageBuilder: (context, state) => FadeThroughPage(
              key: state.pageKey,
              child: const PresentationScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.behavior,
            pageBuilder: (context, state) => FadeThroughPage(
              key: state.pageKey,
              child: const BehaviorScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.ai,
            pageBuilder: (context, state) => FadeThroughPage(
              key: state.pageKey,
              child: const ChatScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (context, state) => FadeThroughPage(
              key: state.pageKey,
              child: const SettingsScreen(),
            ),
          ),
        ],
      ),
    ],
  );
});
