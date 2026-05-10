import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';

/// Small accent-tinted square that hosts an icon. The unifying glyph
/// container used at the start of nearly every list row, stat card and
/// feature tile in v2.
class IconChip extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final double size;
  final double iconSize;
  final double radius;

  const IconChip({
    super.key,
    required this.icon,
    required this.accent,
    this.size = 40,
    this.iconSize = 20,
    this.radius = AppRadius.s,
  });

  /// Slightly larger variant used as a card lead glyph.
  const IconChip.large({
    super.key,
    required this.icon,
    required this.accent,
  })  : size = 48,
        iconSize = 24,
        radius = AppRadius.m;

  /// Compact variant for inline labels.
  const IconChip.small({
    super.key,
    required this.icon,
    required this.accent,
  })  : size = 28,
        iconSize = 14,
        radius = AppRadius.s;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final fillAlpha = brightness == Brightness.dark ? 0.20 : 0.12;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: fillAlpha),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, color: accent, size: iconSize),
    );
  }
}
