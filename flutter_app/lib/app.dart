import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'ui/widgets/login_success_overlay.dart';

class TeacherToolApp extends ConsumerStatefulWidget {
  const TeacherToolApp({super.key});

  @override
  ConsumerState<TeacherToolApp> createState() => _TeacherToolAppState();
}

class _TeacherToolAppState extends ConsumerState<TeacherToolApp> {
  bool _initializing = true;
  bool _showSuccess = false;
  bool _wasLoggedIn = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(authStateProvider.notifier).checkLoginStatus();
      if (!mounted) return;
      _wasLoggedIn = ref.read(authStateProvider).isLoggedIn;
      setState(() => _initializing = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(themeProvider);
    final router = ref.watch(routerProvider);
    final palette = prefs.palette;

    // Detect logged-out → logged-in transition for celebration overlay.
    ref.listen<AuthState>(authStateProvider, (prev, next) {
      if (!_wasLoggedIn && next.isLoggedIn && !_showSuccess) {
        setState(() => _showSuccess = true);
      }
      if (next.isLoggedIn) _wasLoggedIn = true;
      if (!next.isLoggedIn) {
        _wasLoggedIn = false;
        if (_showSuccess) setState(() => _showSuccess = false);
      }
    });

    if (_initializing) {
      return MaterialApp(
        theme: themeDataFor(prefs),
        darkTheme: darkThemeDataFor(prefs),
        themeMode: prefs.mode,
        debugShowCheckedModeBanner: false,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          MaterialApp.router(
            title: 'Teacher Tool',
            theme: themeDataFor(prefs),
            darkTheme: darkThemeDataFor(prefs),
            themeMode: prefs.mode,
            debugShowCheckedModeBanner: false,
            routerConfig: router,
          ),
          if (_showSuccess)
            LoginSuccessOverlay(
              palette: palette,
              greeting: _greetingFor(
                ref.read(authStateProvider).user?.phone ?? '',
              ),
              onComplete: () {
                if (mounted) setState(() => _showSuccess = false);
              },
            ),
        ],
      ),
    );
  }

  String _greetingFor(String phone) {
    final hour = DateTime.now().hour;
    String time;
    if (hour < 6) {
      time = '夜深了';
    } else if (hour < 12) {
      time = '早上好';
    } else if (hour < 14) {
      time = '中午好';
    } else if (hour < 18) {
      time = '下午好';
    } else {
      time = '晚上好';
    }
    final shortName =
        phone.length >= 4 ? phone.substring(phone.length - 4) : phone;
    return shortName.isEmpty ? '$time，老师' : '$time，$shortName 老师';
  }
}
