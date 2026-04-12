import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'ui/screens/auth/login_screen.dart';
import 'ui/screens/home/home_screen.dart';

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

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // For now, show login screen
    return const LoginScreen();
  }
}
