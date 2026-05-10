import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/design/tokens.dart';

/// Standard empty-state. Icon + title + body + (optional) action button.
class EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final Color? accent;
  final EdgeInsets padding;

  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.accent,
    this.padding =
        const EdgeInsets.symmetric(horizontal: AppSpacing.gap5, vertical: AppSpacing.gap6),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = accent ?? scheme.primary;
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.l),
            ),
            child: Icon(icon, color: tone, size: 36),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(
                begin: -3,
                end: 3,
                duration: const Duration(milliseconds: 1800),
                curve: Curves.easeInOutSine,
              ),
          const SizedBox(height: AppSpacing.gap4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
              letterSpacing: -0.2,
            ),
          )
              .animate(delay: const Duration(milliseconds: 200))
              .fadeIn(duration: AppMotion.medium)
              .moveY(begin: 8, end: 0),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.gap2),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: scheme.onSurfaceVariant,
                height: 1.55,
              ),
            )
                .animate(delay: const Duration(milliseconds: 350))
                .fadeIn(duration: AppMotion.medium)
                .moveY(begin: 8, end: 0),
          ],
          if (action != null) ...[
            const SizedBox(height: AppSpacing.gap5),
            action!
                .animate(delay: const Duration(milliseconds: 500))
                .fadeIn(duration: AppMotion.medium)
                .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),
          ],
        ],
      ),
    );
  }
}
