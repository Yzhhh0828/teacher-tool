# Lottie animations

Animations are loaded from public LottieFiles URLs at runtime via
`Lottie.network(...)` so the bundle stays light. If you want offline-safe
playback, drop matching JSON files here and switch the loader to
`Lottie.asset('assets/lottie/<name>.json')` in `lib/ui/widgets/lottie_overlay.dart`.

Suggested local fallbacks (free, MIT/CC0 from lottiefiles.com):

- `login_success.json`     — success check
- `loading_dots.json`      — loading
- `empty_box.json`         — empty state
- `confetti.json`          — celebration
- `chalk_drawing.json`     — login hero
- `error_oops.json`        — error state
