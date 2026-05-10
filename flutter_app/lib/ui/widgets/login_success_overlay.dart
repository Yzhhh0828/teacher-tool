import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/design/tokens.dart';

/// Full-screen success overlay shown right after a user logs in.
///
/// Sequence:
///  - Backdrop fades in (220ms)
///  - Hero circle scales in with a spring (380ms)
///  - White checkmark draws (340ms)
///  - "登录成功 · 欢迎"标语 fade + slide up (240ms)
///  - After [holdDuration] elapses, the overlay fades itself out and
///    triggers [onComplete] to let the parent rebuild into the Shell.
class LoginSuccessOverlay extends StatefulWidget {
  final AppPalette palette;
  final String greeting;
  final VoidCallback onComplete;
  final Duration holdDuration;

  const LoginSuccessOverlay({
    super.key,
    required this.palette,
    required this.greeting,
    required this.onComplete,
    this.holdDuration = const Duration(milliseconds: 1200),
  });

  @override
  State<LoginSuccessOverlay> createState() => _LoginSuccessOverlayState();
}

class _LoginSuccessOverlayState extends State<LoginSuccessOverlay> {
  bool _hiding = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.holdDuration, () {
      if (!mounted) return;
      setState(() => _hiding = true);
      // Wait for fade-out before notifying parent to swap in the Shell.
      Future.delayed(const Duration(milliseconds: 320), widget.onComplete);
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return AnimatedOpacity(
      opacity: _hiding ? 0 : 1,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Solid backdrop using the brand surface so the underlying
            // login form is fully obscured during the celebration.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppGradient.aurora(widget.palette, brightness),
                ),
              ),
            )
                .animate()
                .fadeIn(duration: const Duration(milliseconds: 220)),
            // Soft particles drifting up.
            ..._buildParticles(),
            // Hero content.
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SuccessBadge(palette: widget.palette),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    '登录成功',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  )
                      .animate(delay: const Duration(milliseconds: 380))
                      .fadeIn(duration: const Duration(milliseconds: 240))
                      .moveY(
                        begin: 12,
                        end: 0,
                        duration: const Duration(milliseconds: 240),
                        curve: AppMotion.standard,
                      ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    widget.greeting,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                      .animate(delay: const Duration(milliseconds: 460))
                      .fadeIn(duration: const Duration(milliseconds: 220)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildParticles() {
    final rng = math.Random(7);
    return List.generate(14, (i) {
      final dx = rng.nextDouble();
      final size = 5.0 + rng.nextDouble() * 7;
      final color = [
        widget.palette.accent1,
        widget.palette.accent2,
        widget.palette.accent3,
        widget.palette.tertiary,
      ][i % 4]
          .withValues(alpha: 0.85);
      return Positioned(
        left: dx * MediaQuery.of(context).size.width,
        bottom: -20,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        )
            .animate(delay: Duration(milliseconds: 200 + (i * 40)))
            .fadeIn(duration: const Duration(milliseconds: 200))
            .moveY(
              begin: 0,
              end: -(220 + rng.nextDouble() * 320),
              duration: Duration(milliseconds: 1100 + rng.nextInt(500)),
              curve: Curves.easeOutCubic,
            )
            .fadeOut(
              delay: const Duration(milliseconds: 600),
              duration: const Duration(milliseconds: 600),
            ),
      );
    });
  }
}

class _SuccessBadge extends StatelessWidget {
  final AppPalette palette;
  const _SuccessBadge({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.seed, palette.tertiary, palette.accent3],
        ),
        boxShadow: [
          BoxShadow(
            color: palette.seed.withValues(alpha: 0.5),
            blurRadius: 36,
            spreadRadius: 4,
          ),
        ],
      ),
      child: const _CheckmarkPainterWidget(),
    )
        .animate()
        .scale(
          begin: const Offset(0.4, 0.4),
          end: const Offset(1, 1),
          duration: const Duration(milliseconds: 380),
          curve: AppMotion.spring,
        )
        .then(delay: const Duration(milliseconds: 80))
        .shimmer(
          duration: const Duration(milliseconds: 700),
          color: Colors.white.withValues(alpha: 0.5),
        );
  }
}

class _CheckmarkPainterWidget extends StatefulWidget {
  const _CheckmarkPainterWidget();

  @override
  State<_CheckmarkPainterWidget> createState() =>
      _CheckmarkPainterWidgetState();
}

class _CheckmarkPainterWidgetState extends State<_CheckmarkPainterWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    Future.delayed(const Duration(milliseconds: 280), () {
      if (mounted) _ctl.forward();
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, __) => CustomPaint(
        painter: _CheckmarkPainter(progress: _ctl.value),
      ),
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final double progress;
  _CheckmarkPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final w = size.width;
    final h = size.height;
    final p1 = Offset(w * 0.27, h * 0.52);
    final p2 = Offset(w * 0.45, h * 0.69);
    final p3 = Offset(w * 0.74, h * 0.38);

    // Two-segment stroke; progress 0..0.45 draws p1->p2; 0.45..1 draws p2->p3.
    final path = Path()..moveTo(p1.dx, p1.dy);
    if (progress <= 0.45) {
      final t = progress / 0.45;
      path.lineTo(
        p1.dx + (p2.dx - p1.dx) * t,
        p1.dy + (p2.dy - p1.dy) * t,
      );
    } else {
      path.lineTo(p2.dx, p2.dy);
      final t = (progress - 0.45) / 0.55;
      path.lineTo(
        p2.dx + (p3.dx - p2.dx) * t,
        p2.dy + (p3.dy - p2.dy) * t,
      );
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter old) =>
      old.progress != progress;
}
