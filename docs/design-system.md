# Design System

The Flutter app exposes a small but opinionated design system. It is
**additive** — the legacy warm-orange theme remains the default and is
guaranteed pixel-stable for existing screens.

## Tokens — `lib/core/design/tokens.dart`

| Token | Values |
|-------|--------|
| `AppSpacing` | `xxs=2, xs=4, sm=8, md=12, lg=16, xl=20, xxl=24, xxxl=32` |
| `AppRadius`  | `xs=6, sm=10, md=14, lg=18, xl=24, pill=999` |
| `AppElevation` | `card=0, raised=2, floating=6` |
| `AppMotion` | `micro=120ms, short=220ms, medium=360ms, long=520ms`; curves `emphasized`, `standard`, `spring` |

## Palettes — `AppPalette`

Two ship-ready palettes, each a `ColorScheme.fromSeed`-friendly bundle
plus accent surfaces used by custom widgets:

* **`warmOrange`** *(default)* — preserves the existing teacher-tool
  brand. Maps to the legacy hand-tuned `AppTheme.lightTheme`.
* **`mellardGreen`** — Material 3 Expressive seeded at `#2F8F6E`.
  Built via `buildAppTheme(palette)`.

Switching between palettes is done from **Settings → 外观 → 主题色板**.
The choice is persisted with `shared_preferences` and re-applied on
launch.

## Reusable widgets — `lib/ui/widgets/`

| Widget | Use case |
|--------|----------|
| `AppCard` | Standard surface with rounded corners, soft shadow, optional `onTap`. |
| `GlassPanel` | Translucent hero/presentation surface for ambient backdrops. |
| `AnimatedNumber` | Tween-animated numeric counter for dashboards. |
| `NameWheel` | Spinning name picker used by the random-pick screen — accelerates, then settles on the chosen result. |

## Motion guidelines

Use `AppMotion.short` for hover/press feedback, `AppMotion.medium` for
panel transitions, and `AppMotion.long` only for narrative reveals
(e.g. wheel-picker spin-down). Always pair durations with
`AppMotion.standard` or `AppMotion.emphasized` curves; keep `spring`
reserved for celebratory moments.

## Theming a new screen

```dart
@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  return Scaffold(
    appBar: AppBar(title: const Text('My Screen')),
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AppCard(
          child: Text('Hello', style: theme.textTheme.titleMedium),
        ),
      ],
    ),
  );
}
```

Always go through `Theme.of(context)` and `AppSpacing` / `AppRadius`
constants — never hard-code colours or magic spacing numbers in new
screens. The legacy palette constants in `core/theme/app_theme.dart`
exist only to keep the original screens visually frozen.
