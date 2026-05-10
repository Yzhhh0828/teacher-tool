import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Trigger a horizontal shake on a child whenever [trigger] changes.
class Shake extends StatefulWidget {
  final Object trigger;
  final Widget child;
  final double amplitude;
  final Duration duration;

  const Shake({
    super.key,
    required this.trigger,
    required this.child,
    this.amplitude = 10,
    this.duration = const Duration(milliseconds: 360),
  });

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didUpdateWidget(covariant Shake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        // 4 full cycles across t ∈ [0, 1] with quadratic decay.
        final t = _ctrl.value;
        final dx = t == 0
            ? 0.0
            : widget.amplitude *
                (1 - t) *
                (1 - t) *
                math.sin(t * math.pi * 8);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}
