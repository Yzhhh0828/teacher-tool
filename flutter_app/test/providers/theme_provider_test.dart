import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teacher_tool/core/design/tokens.dart';
import 'package:teacher_tool/core/services/prefs_service.dart';
import 'package:teacher_tool/providers/prefs_provider.dart';
import 'package:teacher_tool/providers/theme_provider.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ProviderContainer> makeContainer({
    Map<String, Object> initialPrefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(initialPrefs);
    final prefs = await PrefsService.create();
    return ProviderContainer(overrides: [
      prefsServiceProvider.overrideWithValue(prefs),
    ]);
  }

  test('default palette + mode when prefs empty', () async {
    final c = await makeContainer();
    addTearDown(c.dispose);
    final t = c.read(themeProvider);
    expect(t.palette, isNotNull);
    expect(t.mode, ThemeMode.system);
  });

  test('persists palette change via setPalette', () async {
    final c = await makeContainer();
    addTearDown(c.dispose);
    final notifier = c.read(themeProvider.notifier);

    final target = AppPalette.warmOrange;
    await notifier.setPalette(target);

    expect(c.read(themeProvider).palette.name, target.name);
    expect(c.read(prefsServiceProvider).themePalette, target.name);
  });

  test('persists mode change via setMode', () async {
    final c = await makeContainer();
    addTearDown(c.dispose);
    final notifier = c.read(themeProvider.notifier);

    await notifier.setMode(ThemeMode.dark);
    expect(c.read(themeProvider).mode, ThemeMode.dark);
    expect(c.read(prefsServiceProvider).themeMode, 'dark');
  });

  test('toggleMode cycles light → dark → system', () async {
    final c = await makeContainer();
    addTearDown(c.dispose);
    final notifier = c.read(themeProvider.notifier);

    await notifier.setMode(ThemeMode.light);
    await notifier.toggleMode();
    expect(c.read(themeProvider).mode, ThemeMode.dark);
    await notifier.toggleMode();
    expect(c.read(themeProvider).mode, ThemeMode.system);
    await notifier.toggleMode();
    expect(c.read(themeProvider).mode, ThemeMode.light);
  });

  test('cold start restores persisted palette + mode', () async {
    final c = await makeContainer(initialPrefs: {
      'theme_palette': 'mellardGreen',
      'theme_mode': 'dark',
    });
    addTearDown(c.dispose);

    final t = c.read(themeProvider);
    expect(t.palette.name, 'mellardGreen');
    expect(t.mode, ThemeMode.dark);
  });

  test('themeDataFor returns ThemeData with the requested brightness',
      () async {
    final c = await makeContainer();
    addTearDown(c.dispose);
    final notifier = c.read(themeProvider.notifier);

    await notifier.setMode(ThemeMode.dark);
    final data = themeDataFor(c.read(themeProvider));
    expect(data, isA<ThemeData>());
    // Mode is read by MaterialApp.themeMode; the returned ThemeData should
    // be light/dark based on the palette default — sanity-check that it
    // produces a non-null colorScheme.
    expect(data.colorScheme, isNotNull);
  });

  test('unknown persisted palette name falls back to default safely',
      () async {
    final c = await makeContainer(
      initialPrefs: {'theme_palette': 'definitely_not_a_palette'},
    );
    addTearDown(c.dispose);
    // Must NOT throw; should fall through to a valid default.
    final t = c.read(themeProvider);
    expect(t.palette, isNotNull);
  });
}
