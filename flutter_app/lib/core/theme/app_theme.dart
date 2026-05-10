import 'package:flutter/material.dart';

import '../design/theme_builder.dart';
import '../design/tokens.dart';

/// Legacy palette constants kept for widgets that still reference them by
/// name (e.g. `AppTheme.primaryColor`). New code should prefer
/// `Theme.of(context).colorScheme.*` + [AppSpacing]/[AppRadius] tokens.
///
/// The actual `ThemeData` is now produced by [buildAppTheme] so that light
/// and dark modes stay in sync and all Material 3 component themes come
/// from a single source of truth.
class AppTheme {
  // Warm Orange Minimal Palette — these mirror [AppPalette.warmOrange].
  static const Color primaryColor = Color(0xFFE07A3F);
  static const Color primaryDark = Color(0xFFB85D28);
  static const Color accent = Color(0xFFF5A468);
  static const Color backgroundLight = Color(0xFFFAFAF7);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF5F2EC);
  static const Color textPrimary = Color(0xFF2D2418);
  static const Color textSecondary = Color(0xFF8C7B68);
  static const Color dividerColor = Color(0xFFEDE8E1);
  static const Color borderLight = Color(0xFFEDE8E1);
  static const Color errorColor = Color(0xFFD94F3D);
  static const Color successColor = Color(0xFF5A9E72);

  static const double radius = AppRadius.lg;
  static const double contentMaxWidth = 480.0;

  /// Light theme used by default. Delegates to [buildAppTheme] so the
  /// styling rules live in one place.
  static ThemeData get lightTheme =>
      buildAppTheme(AppPalette.vibrant, brightness: Brightness.light);

  /// Presentation mode theme (oversized typography) for classroom display.
  static ThemeData get presentationTheme {
    final base = lightTheme;
    final t = base.textTheme;
    return base.copyWith(
      textTheme: t.copyWith(
        displayLarge: t.displayLarge?.copyWith(fontSize: 72, fontWeight: FontWeight.bold),
        displayMedium: t.displayMedium?.copyWith(fontSize: 56, fontWeight: FontWeight.bold),
        displaySmall: t.displaySmall?.copyWith(fontSize: 44, fontWeight: FontWeight.bold),
        headlineLarge: t.headlineLarge?.copyWith(fontSize: 40),
        headlineMedium: t.headlineMedium?.copyWith(fontSize: 32),
        titleLarge: t.titleLarge?.copyWith(fontSize: 28),
        bodyLarge: t.bodyLarge?.copyWith(fontSize: 24),
        bodyMedium: t.bodyMedium?.copyWith(fontSize: 20),
      ),
    );
  }
}
