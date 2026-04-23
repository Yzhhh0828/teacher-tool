import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'ui/screens/auth/login_screen.dart';
import 'ui/shell_scaffold.dart';

class TeacherToolApp extends ConsumerStatefulWidget {
  const TeacherToolApp({super.key});

  @override
  ConsumerState<TeacherToolApp> createState() => _TeacherToolAppState();
}

class _TeacherToolAppState extends ConsumerState<TeacherToolApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Teacher Tool',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(authStateProvider.notifier).checkLoginStatus();
      if (mounted) setState(() => _initializing = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    if (_initializing) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (authState.isLoggedIn) {
      return const ShellScaffold();
    }

    return const LoginScreen();
  }
}
