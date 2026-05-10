import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../core/design/tokens.dart';

/// Public LottieFiles URLs for animations referenced across the app.
/// (Free / MIT / CC0 — used at runtime to keep the bundle small.)
class LottieAssets {
  static const successCheck =
      'https://assets3.lottiefiles.com/packages/lf20_lk80fpsm.json';
  static const loading =
      'https://assets10.lottiefiles.com/packages/lf20_x62chJ.json';
  static const empty =
      'https://assets1.lottiefiles.com/packages/lf20_ydo1amjm.json';
  static const confetti =
      'https://assets1.lottiefiles.com/packages/lf20_obhph3sh.json';
  static const chalkboard =
      'https://assets3.lottiefiles.com/packages/lf20_w51pcehl.json';
  static const errorOops =
      'https://assets10.lottiefiles.com/packages/lf20_qpwbqki6.json';
}

/// Lazy lottie loader with a graceful fallback when offline.
class LottieView extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final bool repeat;
  final Widget? fallback;

  const LottieView({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.repeat = true,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return Lottie.network(
      url,
      width: width,
      height: height,
      repeat: repeat,
      errorBuilder: (_, __, ___) =>
          fallback ?? const SizedBox.shrink(),
    );
  }
}

/// Show a one-shot Lottie overlay that auto-dismisses.
Future<void> showLottieOverlay(
  BuildContext context, {
  required String url,
  Duration duration = const Duration(milliseconds: 1400),
  String? message,
  Color? backdrop,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final navigator = Navigator.of(context, rootNavigator: true);
  Future.delayed(duration, () {
    if (navigator.canPop()) navigator.pop();
  });
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor:
        backdrop ?? scheme.scrim.withValues(alpha: 0.55),
    transitionDuration: AppMotion.short,
    pageBuilder: (_, __, ___) => Center(
      child: Material(
        color: Colors.transparent,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.85, end: 1.0),
          duration: AppMotion.medium,
          curve: AppMotion.spring,
          builder: (_, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: AppShadow.floating(scheme.shadow),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LottieView(url: url, width: 160, height: 160, repeat: false),
                if (message != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
