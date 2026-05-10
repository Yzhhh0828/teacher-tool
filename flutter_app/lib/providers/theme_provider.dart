import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/theme_builder.dart';
import '../core/design/tokens.dart';
import '../core/services/prefs_service.dart';
import 'prefs_provider.dart';

class ThemePrefs {
  final AppPalette palette;
  final ThemeMode mode;
  const ThemePrefs({required this.palette, required this.mode});

  ThemePrefs copyWith({AppPalette? palette, ThemeMode? mode}) =>
      ThemePrefs(palette: palette ?? this.palette, mode: mode ?? this.mode);
}

class ThemeNotifier extends StateNotifier<ThemePrefs> {
  final PrefsService _prefs;

  ThemeNotifier(this._prefs) : super(_loadInitial(_prefs));

  static ThemePrefs _loadInitial(PrefsService prefs) {
    final p = prefs.themePalette;
    final m = prefs.themeMode;
    return ThemePrefs(
      // First-run users (no prefs persisted yet) default to the vibrant palette.
      palette: p == null ? AppPalette.vibrant : AppPalette.byName(p),
      mode: switch (m) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.system,
      },
    );
  }

  Future<void> toggleMode() async {
    final next = switch (state.mode) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
      ThemeMode.system => ThemeMode.light,
    };
    await setMode(next);
  }

  Future<void> setPalette(AppPalette palette) async {
    state = state.copyWith(palette: palette);
    await _prefs.setThemePalette(palette.name);
  }

  Future<void> setMode(ThemeMode mode) async {
    state = state.copyWith(mode: mode);
    await _prefs.setThemeMode(mode.name);
  }
}

final themeProvider =
    StateNotifierProvider<ThemeNotifier, ThemePrefs>((ref) {
  return ThemeNotifier(ref.read(prefsServiceProvider));
});

ThemeData themeDataFor(ThemePrefs prefs) =>
    buildAppTheme(prefs.palette, brightness: Brightness.light);

ThemeData darkThemeDataFor(ThemePrefs prefs) =>
    buildAppTheme(prefs.palette, brightness: Brightness.dark);
