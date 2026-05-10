import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/services/prefs_service.dart';
import 'providers/prefs_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Wait for SharedPreferences once at startup so providers can read it
  // synchronously and avoid a flash of "default" UI before persistence
  // kicks in.
  final prefs = await PrefsService.create();
  runApp(
    ProviderScope(
      overrides: [
        prefsServiceProvider.overrideWithValue(prefs),
      ],
      child: const TeacherToolApp(),
    ),
  );
}
