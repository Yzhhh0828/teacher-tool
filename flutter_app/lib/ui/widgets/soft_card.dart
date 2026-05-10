import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';

/// The default surface used by 90 % of cards in the v2 design.
///
/// - Plain white/dark surface with a 1 px outline + subtle shadow.
/// - Optional [accent] adds a left 3 px stripe and a faint hover wash —
///   this is how a card "tells the user which module it belongs to" without
///   flooding the entire surface.
/// - Hover/press feedback is implemented with **color/shadow only** — no
///   scale or layout-shifting transforms (per ui-ux-pro-max
///   `stable-hover-states`).
class SoftCard extends StatefulWidget {
  final Widget child;
  final Color? accent;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final bool dense;

  const SoftCard({
    super.key,
    required this.child,
    this.accent,
    this.padding = const EdgeInsets.all(AppSpacing.gap4),
    this.radius = AppRadius.m,
    this.onTap,
    this.dense = false,
  });

  @override
  State<SoftCard> createState() => _SoftCardState();
}

class _SoftCardState extends State<SoftCard> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final accent = widget.accent;

    final hoverWashAlpha = brightness == Brightness.dark ? 0.08 : 0.05;
    final base = scheme.surface;
    final fill = (_hover || _pressed) && accent != null
        ? Color.alphaBlend(accent.withValues(alpha: hoverWashAlpha), base)
        : base;

    final shadow = _hover && widget.onTap != null
        ? AppShadow.raised(scheme.shadow)
        : AppShadow.subtle(scheme.shadow);

    final borderColor = accent != null && _hover
        ? accent.withValues(alpha: 0.45)
        : scheme.outlineVariant;

    final card = AnimatedContainer(
      duration: AppMotion.short,
      curve: AppMotion.standard,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: shadow,
      ),
      child: widget.child,
    );

    Widget body = card;
    if (accent != null) {
      // Left 3 px stripe — module identity without colourising the whole card.
      body = ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: Stack(
          children: [
            card,
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 3,
              child: AnimatedContainer(
                duration: AppMotion.short,
                color: accent.withValues(alpha: _hover ? 1.0 : 0.85),
              ),
            ),
          ],
        ),
      );
    }

    if (widget.onTap == null) return body;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: AppMotion.micro,
          curve: AppMotion.standard,
          child: body,
        ),
      ),
    );
  }
}
