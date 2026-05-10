import 'package:flutter/material.dart';
import '../../core/design/tokens.dart';

/// Smoothly tween-animated numeric display.
class AnimatedNumber extends StatelessWidget {
  final num value;
  final TextStyle? style;
  final int fractionDigits;
  final Duration duration;
  final String prefix;
  final String suffix;

  const AnimatedNumber({
    super.key,
    required this.value,
    this.style,
    this.fractionDigits = 0,
    this.duration = AppMotion.medium,
    this.prefix = '',
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: AppMotion.emphasized,
      builder: (context, v, _) {
        final text = '$prefix${v.toStringAsFixed(fractionDigits)}$suffix';
        return Text(text, style: style);
      },
    );
  }
}
