import 'package:flutter/material.dart';

import 'lottie_overlay.dart';

/// A thin convenience wrapper that fires a confetti Lottie overlay on tap.
class ConfettiAction {
  static Future<void> celebrate(
    BuildContext context, {
    String? message,
    Duration duration = const Duration(milliseconds: 1600),
  }) {
    return showLottieOverlay(
      context,
      url: LottieAssets.confetti,
      message: message,
      duration: duration,
    );
  }

  static Future<void> success(
    BuildContext context, {
    String? message,
    Duration duration = const Duration(milliseconds: 1300),
  }) {
    return showLottieOverlay(
      context,
      url: LottieAssets.successCheck,
      message: message,
      duration: duration,
    );
  }

  static Future<void> error(
    BuildContext context, {
    String? message,
    Duration duration = const Duration(milliseconds: 1400),
  }) {
    return showLottieOverlay(
      context,
      url: LottieAssets.errorOops,
      message: message,
      duration: duration,
    );
  }
}
