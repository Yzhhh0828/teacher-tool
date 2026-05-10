import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralised wrapper around SharedPreferences for non-sensitive user
/// preferences. Sensitive items (auth tokens, API keys) still live in
/// [FlutterSecureStorage] via the relevant providers.
///
/// Keep this class small and *typed*: every key gets its own getter/setter so
/// typos can't sneak in and tests can mock individual entries.
class PrefsService {
  static const _kThemePalette = 'theme_palette';
  static const _kThemeMode = 'theme_mode';
  static const _kCurrentClassId = 'current_class_id';
  static const _kLastTabPath = 'last_tab_path';
  static const _kMoodPrefix = 'mood_'; // mood_YYYY-MM-DD = "happy"
  static const _kCustomQuotes = 'custom_quotes'; // JSON array of strings

  final SharedPreferences _prefs;
  PrefsService._(this._prefs);

  static Future<PrefsService> create() async {
    final p = await SharedPreferences.getInstance();
    return PrefsService._(p);
  }

  /// For tests / overrides.
  factory PrefsService.fromInstance(SharedPreferences prefs) =>
      PrefsService._(prefs);

  // ── Theme ──────────────────────────────────────────────────────────────
  String? get themePalette => _prefs.getString(_kThemePalette);
  Future<void> setThemePalette(String name) =>
      _prefs.setString(_kThemePalette, name);

  String? get themeMode => _prefs.getString(_kThemeMode);
  Future<void> setThemeMode(String mode) => _prefs.setString(_kThemeMode, mode);

  // ── Current class ──────────────────────────────────────────────────────
  int? get currentClassId => _prefs.getInt(_kCurrentClassId);
  Future<void> setCurrentClassId(int? id) async {
    if (id == null) {
      await _prefs.remove(_kCurrentClassId);
    } else {
      await _prefs.setInt(_kCurrentClassId, id);
    }
  }

  // ── Last visited tab path ──────────────────────────────────────────────
  String? get lastTabPath => _prefs.getString(_kLastTabPath);
  Future<void> setLastTabPath(String? path) async {
    if (path == null) {
      await _prefs.remove(_kLastTabPath);
    } else {
      await _prefs.setString(_kLastTabPath, path);
    }
  }

  // ── Mood (per-day) ─────────────────────────────────────────────────────
  String _moodKey(DateTime day) =>
      '$_kMoodPrefix${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  String? moodFor(DateTime day) => _prefs.getString(_moodKey(day));
  Future<void> setMoodFor(DateTime day, String mood) =>
      _prefs.setString(_moodKey(day), mood);

  // ── Custom quotes (user-added) ─────────────────────────────────────────
  List<String> get customQuotes {
    final raw = _prefs.getString(_kCustomQuotes);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is List) return list.map((e) => e.toString()).toList();
    } catch (_) {}
    return const [];
  }

  Future<void> setCustomQuotes(List<String> quotes) =>
      _prefs.setString(_kCustomQuotes, jsonEncode(quotes));

  Future<void> addCustomQuote(String quote) async {
    final list = customQuotes.toList()..add(quote);
    await setCustomQuotes(list);
  }

  Future<void> removeCustomQuote(String quote) async {
    final list = customQuotes.where((q) => q != quote).toList();
    await setCustomQuotes(list);
  }

  // ── Logout / wipe ──────────────────────────────────────────────────────
  /// Clear everything that's user-session bound (currentClassId, lastTabPath,
  /// mood). Theme preferences and custom quotes intentionally survive a
  /// logout so the new login lands on the same look-and-feel.
  Future<void> clearSessionPrefs() async {
    await _prefs.remove(_kCurrentClassId);
    await _prefs.remove(_kLastTabPath);
    // Mood keys are date-scoped; we leave them as a personal log.
  }
}
