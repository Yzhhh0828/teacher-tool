import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teacher_tool/core/services/prefs_service.dart';

void main() {
  // Each test gets its own in-memory backing store via setMockInitialValues.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PrefsService — theme', () {
    test('returns null on first run, persists palette and mode', () async {
      final p = await PrefsService.create();
      expect(p.themePalette, isNull);
      expect(p.themeMode, isNull);

      await p.setThemePalette('warmOrange');
      await p.setThemeMode('dark');

      // Recreate to simulate cold restart.
      final p2 = await PrefsService.create();
      expect(p2.themePalette, 'warmOrange');
      expect(p2.themeMode, 'dark');
    });
  });

  group('PrefsService — currentClass', () {
    test('persists and clears class id', () async {
      final p = await PrefsService.create();
      expect(p.currentClassId, isNull);

      await p.setCurrentClassId(42);
      expect(p.currentClassId, 42);

      await p.setCurrentClassId(null);
      expect(p.currentClassId, isNull);
    });

    test('survives a simulated restart', () async {
      SharedPreferences.setMockInitialValues({'current_class_id': 99});
      final p = await PrefsService.create();
      expect(p.currentClassId, 99);
    });
  });

  group('PrefsService — mood (per day)', () {
    test('mood is keyed by date', () async {
      final p = await PrefsService.create();
      final today = DateTime(2026, 5, 10);
      final tomorrow = DateTime(2026, 5, 11);
      expect(p.moodFor(today), isNull);
      await p.setMoodFor(today, 'happy');
      expect(p.moodFor(today), 'happy');
      expect(p.moodFor(tomorrow), isNull);
    });
  });

  group('PrefsService — custom quotes', () {
    test('add/list/remove round-trip', () async {
      final p = await PrefsService.create();
      expect(p.customQuotes, isEmpty);

      await p.addCustomQuote('坚持就是胜利');
      await p.addCustomQuote('天道酬勤');
      expect(p.customQuotes, ['坚持就是胜利', '天道酬勤']);

      await p.removeCustomQuote('坚持就是胜利');
      expect(p.customQuotes, ['天道酬勤']);
    });

    test('handles malformed json gracefully', () async {
      SharedPreferences.setMockInitialValues({'custom_quotes': 'not json'});
      final p = await PrefsService.create();
      expect(p.customQuotes, isEmpty);
    });
  });

  group('PrefsService — clearSessionPrefs', () {
    test('removes class + tab path but keeps theme & quotes & mood', () async {
      SharedPreferences.setMockInitialValues({
        'theme_palette': 'mellardGreen',
        'theme_mode': 'dark',
        'current_class_id': 7,
        'last_tab_path': '/students',
        'custom_quotes': '["你好"]',
        'mood_2026-05-10': 'happy',
      });
      final p = await PrefsService.create();
      await p.clearSessionPrefs();
      expect(p.currentClassId, isNull);
      expect(p.lastTabPath, isNull);
      expect(p.themePalette, 'mellardGreen');
      expect(p.themeMode, 'dark');
      expect(p.customQuotes, ['你好']);
      expect(p.moodFor(DateTime(2026, 5, 10)), 'happy');
    });
  });
}
