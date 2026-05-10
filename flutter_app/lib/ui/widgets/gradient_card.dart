import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';

/// A tappable card with optional gradient background, soft shadow, and a
/// subtle press-down spring. Used as the canonical surface for accent cards
/// across home / class / presentation screens.
class GradientCard extends StatefulWidget {
  final Widget child;
  final Gradient? gradient;
  final Color? color;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final List<BoxShadow>? boxShadow;
  final Border? border;

  const GradientCard({
    super.key,
    required this.child,
    this.gradient,
    this.color,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = AppRadius.lg,
    this.boxShadow,
    this.border,
  });

  @override
  State<GradientCard> createState() => _GradientCardState();
}

class _GradientCardState extends State<GradientCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scale = _pressed ? 0.97 : 1.0;

    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: scale,
        duration: AppMotion.short,
        curve: AppMotion.emphasized,
        child: AnimatedContainer(
          duration: AppMotion.short,
          curve: AppMotion.standard,
          padding: widget.padding,
          decoration: BoxDecoration(
            gradient: widget.gradient,
            color: widget.gradient == null
                ? (widget.color ?? scheme.surface)
                : null,
            borderRadius: BorderRadius.circular(widget.radius),
            border: widget.border,
            boxShadow: widget.boxShadow ?? AppShadow.soft(scheme.shadow),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
