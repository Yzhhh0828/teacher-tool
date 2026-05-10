import 'package:flutter/material.dart';

import 'tokens.dart';

/// Build a fully-configured ThemeData from any [AppPalette] and brightness.
///
/// All chrome reads from [scheme] or palette accessors keyed on [brightness],
/// so dark mode actually shifts surfaces, text and dividers — not just the
/// brightness flag.
ThemeData buildAppTheme(
  AppPalette palette, {
  Brightness brightness = Brightness.light,
}) {
  final scheme = palette.toScheme(brightness: brightness);
  final isDark = brightness == Brightness.dark;
  // Bundled CJK font (registered in pubspec.yaml). Avoids CanvasKit's
  // runtime fetch of Noto Sans SC from fonts.gstatic.com (slow + blocked
  // in some networks → tofu boxes + UI lag).
  const fontFamily = 'SimHei';
  final base = (isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme)
      .apply(fontFamily: fontFamily);

  TextStyle? withColor(TextStyle? s, Color c, {FontWeight? w, double? size}) {
    return s?.copyWith(color: c, fontWeight: w, fontSize: size);
  }

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: fontFamily,
    scaffoldBackgroundColor: scheme.surface == palette.surface(brightness)
        ? palette.background(brightness)
        : scheme.surface,
    canvasColor: scheme.surface,
    textTheme: base.copyWith(
      displayLarge:
          withColor(base.displayLarge, scheme.onSurface, w: FontWeight.w800),
      displayMedium:
          withColor(base.displayMedium, scheme.onSurface, w: FontWeight.w800),
      displaySmall:
          withColor(base.displaySmall, scheme.onSurface, w: FontWeight.w700),
      headlineLarge:
          withColor(base.headlineLarge, scheme.onSurface, w: FontWeight.w700),
      headlineMedium:
          withColor(base.headlineMedium, scheme.onSurface, w: FontWeight.w700),
      headlineSmall:
          withColor(base.headlineSmall, scheme.onSurface, w: FontWeight.w700),
      titleLarge: withColor(base.titleLarge, scheme.onSurface,
          w: FontWeight.w700, size: 22),
      titleMedium: withColor(base.titleMedium, scheme.onSurface,
          w: FontWeight.w600, size: 16),
      titleSmall: withColor(base.titleSmall, scheme.onSurface,
          w: FontWeight.w600, size: 14),
      bodyLarge:
          withColor(base.bodyLarge, scheme.onSurface, size: 16),
      bodyMedium:
          withColor(base.bodyMedium, scheme.onSurfaceVariant, size: 14),
      bodySmall:
          withColor(base.bodySmall, scheme.onSurfaceVariant, size: 12),
      labelLarge: withColor(base.labelLarge, scheme.onSurface,
          w: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(color: scheme.onSurface, size: 24),
    ),
    cardTheme: CardThemeData(
      elevation: AppElevation.card,
      color: scheme.surface,
      shadowColor: scheme.shadow,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg)),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: scheme.outlineVariant, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: scheme.error, width: 1.4),
      ),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      hintStyle:
          TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
      prefixIconColor: scheme.onSurfaceVariant,
      suffixIconColor: scheme.onSurfaceVariant,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxxl, vertical: AppSpacing.lg),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        textStyle: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl, vertical: AppSpacing.md),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        textStyle: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.3),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.primary, width: 1.4),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl, vertical: AppSpacing.md),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        textStyle: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: scheme.onSurface,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl)),
      titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700),
      contentTextStyle: TextStyle(
          color: scheme.onSurface, fontSize: 14, height: 1.45),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: scheme.surface,
      modalElevation: 12,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      showDragHandle: true,
      dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.4),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: AppElevation.floating,
      shape: const StadiumBorder(),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md)),
      behavior: SnackBarBehavior.floating,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerHighest,
      selectedColor: scheme.primary.withValues(alpha: 0.18),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill)),
      side: BorderSide(color: scheme.outlineVariant),
      labelStyle: TextStyle(
          color: scheme.onSurface, fontWeight: FontWeight.w600, fontSize: 13),
    ),
    dividerTheme: DividerThemeData(
        color: scheme.outlineVariant, thickness: 1, space: 1),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg)),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      titleTextStyle: TextStyle(
          color: scheme.onSurface, fontSize: 15, fontWeight: FontWeight.w600),
      subtitleTextStyle: TextStyle(
          color: scheme.onSurfaceVariant, fontSize: 13),
      minVerticalPadding: 12,
      iconColor: scheme.onSurfaceVariant,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primary.withValues(alpha: 0.18),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primary.withValues(alpha: 0.16),
      selectedIconTheme: IconThemeData(color: scheme.primary, size: 26),
      unselectedIconTheme: IconThemeData(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.75), size: 26),
      selectedLabelTextStyle: TextStyle(
          color: scheme.primary, fontSize: 13, fontWeight: FontWeight.w700),
      unselectedLabelTextStyle: TextStyle(
          color: scheme.onSurfaceVariant, fontSize: 13),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurfaceVariant,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: scheme.primary, width: 3),
      ),
      labelStyle: const TextStyle(
          fontWeight: FontWeight.w700, fontSize: 14),
      unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500, fontSize: 14),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: scheme.primary,
      inactiveTrackColor: scheme.primary.withValues(alpha: 0.18),
      thumbColor: scheme.primary,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: ZoomPageTransitionsBuilder(),
      },
    ),
  );
}
