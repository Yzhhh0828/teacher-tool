import 'package:flutter/material.dart';

/// Design tokens — single source of truth for spacing, radii, motion, palette.
///
/// v2: locked scales + module accent map + neutral surfaces.

// ─── Spacing ────────────────────────────────────────────────────────────────
// Locked 7-step scale. New code SHOULD use [AppSpacing.gap*] names.
class AppSpacing {
  static const double gap1 = 4;
  static const double gap2 = 8;
  static const double gap3 = 12;
  static const double gap4 = 16;
  static const double gap5 = 24;
  static const double gap6 = 32;
  static const double gap7 = 48;

  /// Default page horizontal padding.
  static const double pagePadding = 20;
  static const double pagePaddingDesktop = 28;

  /// Shell content max width — keeps wide screens readable.
  static const double contentMaxWidth = 980;

  /// NavigationRail widths.
  static const double railWidth = 244;
  static const double railWidthCompact = 76;

  // Legacy aliases (kept for source-compat; do not use in new code).
  static const double xxs = 2;
  static const double xs = gap1;
  static const double sm = gap2;
  static const double md = gap3;
  static const double lg = gap4;
  static const double xl = gap5; // 24
  static const double xxl = gap5;
  static const double xxxl = gap6;
  static const double huge = gap7;
}

// ─── Radius ─────────────────────────────────────────────────────────────────
// Locked 3 + pill scale; default = m.
class AppRadius {
  static const double s = 10;
  static const double m = 14;
  static const double l = 20;
  static const double pill = 999;

  // Legacy aliases.
  static const double xs = s;
  static const double sm = s;
  static const double md = m;
  static const double lg = l;
  static const double xl = l;
  static const double xxl = l;
}

class AppElevation {
  static const double card = 0;
  static const double raised = 2;
  static const double floating = 6;
  static const double overlay = 12;
}

// ─── Motion ─────────────────────────────────────────────────────────────────
// Per ui-ux-pro-max: 150–300 ms for micro-interactions; transform/opacity only.
class AppMotion {
  static const Duration micro = Duration(milliseconds: 120);
  static const Duration short = Duration(milliseconds: 220);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration long = Duration(milliseconds: 480);
  static const Duration grand = Duration(milliseconds: 720);

  /// Stagger interval for list entrances.
  static const Duration stagger = Duration(milliseconds: 40);

  // Calmer curves: no elastic / no bounce by default.
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
  static const Curve standard = Curves.easeOutCubic;
  static const Curve gentle = Curves.easeOutQuart;
  // Soft spring (kept for opt-in usage), no overshoot.
  static const Curve spring = Curves.easeOutBack;
  // Legacy alias (avoid in new code).
  static const Curve bounce = Curves.easeOutCubic;
}

/// Brightness-aware colour set.
///
/// Each [_BrightnessColors] holds the surface / text / divider colours used
/// by both Material widgets and our custom widgets. By splitting light and
/// dark explicitly we avoid leaking light hex literals into dark themes.
class _BrightnessColors {
  final Color surface;
  final Color surfaceElevated; // cards, sheets
  final Color background; // scaffold
  final Color text;
  final Color textSecondary;
  final Color divider;
  final Color shadow;

  const _BrightnessColors({
    required this.surface,
    required this.surfaceElevated,
    required this.background,
    required this.text,
    required this.textSecondary,
    required this.divider,
    required this.shadow,
  });
}

/// Multi-colour, expressive palette tuned for a teaching context.
///
/// `primary` is the main brand colour; `secondary` / `tertiary` / accents
/// make up the multi-colour identity. Each palette knows how to render
/// its scheme + chrome in both light and dark.
class AppPalette {
  final String name;
  final String label; // 中文展示名
  final Color seed; // primary seed
  final Color secondary;
  final Color tertiary;
  final Color accent1; // 玫红 / pink
  final Color accent2; // 明黄 / amber
  final Color accent3; // 薰衣草 / lavender

  final _BrightnessColors _light;
  final _BrightnessColors _dark;

  const AppPalette._({
    required this.name,
    required this.label,
    required this.seed,
    required this.secondary,
    required this.tertiary,
    required this.accent1,
    required this.accent2,
    required this.accent3,
    required _BrightnessColors light,
    required _BrightnessColors dark,
  })  : _light = light,
        _dark = dark;

  // ─── Public accessors ────────────────────────────────────────────────────

  Color surface(Brightness b) =>
      b == Brightness.dark ? _dark.surface : _light.surface;
  Color surfaceElevated(Brightness b) =>
      b == Brightness.dark ? _dark.surfaceElevated : _light.surfaceElevated;
  Color background(Brightness b) =>
      b == Brightness.dark ? _dark.background : _light.background;
  Color text(Brightness b) => b == Brightness.dark ? _dark.text : _light.text;
  Color textSecondary(Brightness b) =>
      b == Brightness.dark ? _dark.textSecondary : _light.textSecondary;
  Color divider(Brightness b) =>
      b == Brightness.dark ? _dark.divider : _light.divider;
  Color shadow(Brightness b) =>
      b == Brightness.dark ? _dark.shadow : _light.shadow;

  /// Build a M3 [ColorScheme] anchored on the brand seed but with our brand
  /// secondary / tertiary explicitly preserved.
  ColorScheme toScheme({Brightness brightness = Brightness.light}) {
    final base = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      secondary: secondary,
      tertiary: tertiary,
    );
    return base.copyWith(
      surface: surface(brightness),
      onSurface: text(brightness),
      onSurfaceVariant: textSecondary(brightness),
      surfaceContainerHighest: surfaceElevated(brightness),
      outlineVariant: divider(brightness),
      shadow: shadow(brightness),
      surfaceTint: Colors.transparent,
    );
  }

  // ─── Predefined palettes ─────────────────────────────────────────────────

  /// Vibrant — default. Sage green primary + warm, high-saturation accents.
  static const vibrant = AppPalette._(
    name: 'vibrant',
    label: '活力多彩',
    seed: Color(0xFF4FA289),
    secondary: Color(0xFFFF8A4C),
    tertiary: Color(0xFF3B82F6),
    accent1: Color(0xFFF472B6),
    accent2: Color(0xFFFACC15),
    accent3: Color(0xFFA78BFA),
    light: _BrightnessColors(
      surface: Color(0xFFFFFFFF),
      surfaceElevated: Color(0xFFF8FAF7),
      background: Color(0xFFF5F7F4),
      text: Color(0xFF15241B),
      textSecondary: Color(0xFF5C6B62),
      divider: Color(0xFFE5E8E2),
      shadow: Color(0x12000000),
    ),
    dark: _BrightnessColors(
      surface: Color(0xFF1A2620),
      surfaceElevated: Color(0xFF22322B),
      background: Color(0xFF0E1612),
      text: Color(0xFFE8EFE9),
      textSecondary: Color(0xFFB7C0B9),
      divider: Color(0xFF2C3A33),
      shadow: Color(0x66000000),
    ),
  );

  /// Warm orange — original brand identity, more saturated than before.
  static const warmOrange = AppPalette._(
    name: 'warmOrange',
    label: '暖橙',
    seed: Color(0xFFE67A3A),
    secondary: Color(0xFF2EA39A),
    tertiary: Color(0xFF6A5CFF),
    accent1: Color(0xFFEF4D5E),
    accent2: Color(0xFFF5C242),
    accent3: Color(0xFF6C9CFF),
    light: _BrightnessColors(
      surface: Color(0xFFFFFFFF),
      surfaceElevated: Color(0xFFFAF6F0),
      background: Color(0xFFFCF7EF),
      text: Color(0xFF2D2418),
      textSecondary: Color(0xFF7C6A55),
      divider: Color(0xFFEBE2D4),
      shadow: Color(0x18000000),
    ),
    dark: _BrightnessColors(
      surface: Color(0xFF26201A),
      surfaceElevated: Color(0xFF332B23),
      background: Color(0xFF18130E),
      text: Color(0xFFF5EDE0),
      textSecondary: Color(0xFFB6A992),
      divider: Color(0xFF3A3128),
      shadow: Color(0x66000000),
    ),
  );

  /// Morandi green — muted sage, calm.
  static const mellardGreen = AppPalette._(
    name: 'mellardGreen',
    label: '莫兰迪绿',
    seed: Color(0xFF7BA191),
    secondary: Color(0xFFCDB57A),
    tertiary: Color(0xFF9DB4C9),
    accent1: Color(0xFFD9A4A4),
    accent2: Color(0xFFE3D293),
    accent3: Color(0xFFB4B7D9),
    light: _BrightnessColors(
      surface: Color(0xFFFCFCFA),
      surfaceElevated: Color(0xFFF5F6F1),
      background: Color(0xFFF1F2EE),
      text: Color(0xFF22302A),
      textSecondary: Color(0xFF6E7A72),
      divider: Color(0xFFE3E5DF),
      shadow: Color(0x10000000),
    ),
    dark: _BrightnessColors(
      surface: Color(0xFF1F2622),
      surfaceElevated: Color(0xFF2A322D),
      background: Color(0xFF141916),
      text: Color(0xFFE3E8E4),
      textSecondary: Color(0xFFA0ACA4),
      divider: Color(0xFF2D3530),
      shadow: Color(0x55000000),
    ),
  );

  static const all = <AppPalette>[vibrant, warmOrange, mellardGreen];

  static AppPalette byName(String? name) {
    return all.firstWhere(
      (p) => p.name == name,
      orElse: () => vibrant,
    );
  }
}

/// Gradients — v2 keeps a single canonical [hero] family.
///
/// Other names (`sunrise`/`aurora`/`ocean`/`candy`) remain as aliases so any
/// stale screen still compiles, but new code should always call [hero] (or
/// the module-scoped variants) so we cap the palette to one identity per
/// screen.
class AppGradient {
  /// Canonical hero gradient: seed → tertiary, alpha tuned per brightness.
  static LinearGradient hero(AppPalette p, Brightness b) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: b == Brightness.dark
            ? [
                p.seed.withValues(alpha: 0.55),
                p.tertiary.withValues(alpha: 0.55),
              ]
            : [
                p.seed.withValues(alpha: 0.95),
                p.tertiary.withValues(alpha: 0.92),
              ],
      );

  /// Two-tone gradient anchored on a single accent (used sparingly: e.g. the
  /// "current class" hero card or presentation big stage).
  static LinearGradient accent(Color a, Brightness b) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: b == Brightness.dark
            ? [a.withValues(alpha: 0.65), a.withValues(alpha: 0.40)]
            : [a, a.withValues(alpha: 0.78)],
      );

  // ── Legacy aliases (kept so older screens still compile). ────────────────
  static LinearGradient sunrise(AppPalette p, Brightness b) => hero(p, b);
  static LinearGradient aurora(AppPalette p, Brightness b) => hero(p, b);
  static LinearGradient ocean(AppPalette p, Brightness b) => hero(p, b);
  static LinearGradient candy(AppPalette p, Brightness b) =>
      accent(p.accent1, b);

  /// Blackboard-feel gradient for presentation mode.
  static const LinearGradient blackboard = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1F2A24), Color(0xFF0F1612)],
  );
}

/// Neutral shadows. v2 removes the "tinted" colored haze that was dialing
/// up chroma noise across cards.
class AppShadow {
  /// Default for content cards. Subtle, near-invisible in dark.
  static List<BoxShadow> subtle(Color baseShadow) => [
        BoxShadow(
          color: baseShadow,
          blurRadius: 12,
          spreadRadius: 0,
          offset: const Offset(0, 2),
        ),
      ];

  /// Hover / pressed elevation.
  static List<BoxShadow> raised(Color baseShadow) => [
        BoxShadow(
          color: baseShadow,
          blurRadius: 24,
          spreadRadius: -2,
          offset: const Offset(0, 8),
        ),
      ];

  /// Hero / floating sheets only.
  static List<BoxShadow> hero(Color baseShadow) => [
        BoxShadow(
          color: baseShadow,
          blurRadius: 40,
          spreadRadius: -4,
          offset: const Offset(0, 16),
        ),
      ];

  // ── Legacy aliases ───────────────────────────────────────────────────────
  static List<BoxShadow> soft(Color baseShadow) => subtle(baseShadow);
  static List<BoxShadow> floating(Color baseShadow) => raised(baseShadow);

  /// Deprecated: tinted colored shadow. Kept for compat but new code must
  /// not create more chroma noise — prefer [subtle].
  static List<BoxShadow> tinted(Color tint) => [
        BoxShadow(
          color: tint.withValues(alpha: 0.18),
          blurRadius: 18,
          spreadRadius: -2,
          offset: const Offset(0, 8),
        ),
      ];
}

/// Semantic, per-module accent colours. Each functional area binds to a
/// fixed palette role so the eye learns "exam = orange / seating = green"
/// across the whole app. This is the v2 antidote to "every card a different
/// rainbow" patchwork feel.
class AppAccent {
  final AppPalette _p;
  const AppAccent(this._p);

  /// Workspace / dashboard.
  Color get home => _p.seed;

  /// Class management & student lists.
  Color get classes => _p.tertiary;
  Color get student => _p.tertiary;

  /// Exams & grades.
  Color get exam => _p.secondary;

  /// Seating chart.
  Color get seating => _p.seed;

  /// Schedule / timetable.
  Color get schedule => _p.accent3;

  /// In-class presentation tools (random call / pick / groups / timer).
  Color get presentation => _p.accent1;

  /// Behavior tracking / leaderboard.
  Color get behavior => _p.accent1;

  /// AI assistant.
  Color get ai => _p.accent2;

  /// Generic / settings (kept neutral on purpose).
  Color get neutral => const Color(0xFF7A8A82);
}

/// Surface helpers — the v2 "single source of truth" for card backgrounds.
///
/// 90 % of cards across the app should pick from this class instead of
/// hand-rolling a [BoxDecoration]. This keeps the palette consistent, makes
/// dark mode automatic and removes the "every card a different gradient"
/// chaos from v1.
class AppSurface {
  /// Plain card: surface fill + 1 px outline + subtle shadow.
  static BoxDecoration card(BuildContext context, {double radius = AppRadius.m}) {
    final scheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: scheme.outlineVariant, width: 1),
      boxShadow: AppShadow.subtle(scheme.shadow),
    );
  }

  /// Tinted card — keeps a card visually grouped with its accent (e.g. a
  /// schedule chip with its subject colour) without flooding the surface.
  static BoxDecoration tinted(
    BuildContext context,
    Color accent, {
    double radius = AppRadius.m,
    double alpha = 0.10,
  }) {
    final brightness = Theme.of(context).brightness;
    final a = brightness == Brightness.dark ? alpha + 0.08 : alpha;
    return BoxDecoration(
      color: accent.withValues(alpha: a),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: accent.withValues(alpha: a + 0.12), width: 1),
    );
  }

  /// Hero card (gradient). Use SPARINGLY — at most one per screen.
  static BoxDecoration hero(
    BuildContext context, {
    required AppPalette palette,
    double radius = AppRadius.l,
    Color? accent,
  }) {
    final brightness = Theme.of(context).brightness;
    final scheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      gradient: accent != null
          ? AppGradient.accent(accent, brightness)
          : AppGradient.hero(palette, brightness),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: AppShadow.hero(scheme.shadow),
    );
  }
}
