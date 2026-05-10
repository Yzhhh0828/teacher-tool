import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/design/tokens.dart';

/// A simple animated "name wheel" used by the random-pick screen.
///
/// The wheel rapidly cycles through the provided names while spinning,
/// gradually slows, and lands on the result. Caller controls start/stop
/// via [running] and is notified through [onSettled] when motion finishes.
class NameWheel extends StatefulWidget {
  final List<String> names;
  final bool running;
  final String? finalName;
  final ValueChanged<String>? onSettled;
  final Duration spinDuration;
  final TextStyle? style;

  const NameWheel({
    super.key,
    required this.names,
    required this.running,
    this.finalName,
    this.onSettled,
    this.spinDuration = const Duration(milliseconds: 1600),
    this.style,
  });

  @override
  State<NameWheel> createState() => _NameWheelState();
}

class _NameWheelState extends State<NameWheel> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: widget.spinDuration);
  final _rng = math.Random();
  String _currentLabel = '';

  @override
  void initState() {
    super.initState();
    _currentLabel = widget.names.isEmpty ? '—' : widget.names[0];
    _ctrl.addListener(_tick);
    if (widget.running) {
      // Schedule for the next frame so callers can complete `pumpWidget`
      // before the spin animation drives any setState.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.running) _spin();
      });
    }
  }

  @override
  void didUpdateWidget(covariant NameWheel old) {
    super.didUpdateWidget(old);
    if (widget.running && !old.running) _spin();
    if (!widget.running && old.running) _ctrl.stop();
  }

  void _spin() async {
    if (widget.names.isEmpty) return;
    _ctrl.reset();
    await _ctrl.animateTo(1.0, curve: Curves.easeOutCubic);
    final landed = widget.finalName ?? widget.names[_rng.nextInt(widget.names.length)];
    setState(() => _currentLabel = landed);
    widget.onSettled?.call(landed);
  }

  void _tick() {
    if (widget.names.isEmpty) return;
    // Faster cycling at the start, slowing as t -> 1
    final t = _ctrl.value;
    final freq = (1 - t) * 18 + 2; // hz (rough)
    final period = 1 / freq;
    final phase = (t * widget.spinDuration.inMilliseconds / 1000) % period;
    if (phase < 0.04) {
      final next = widget.names[_rng.nextInt(widget.names.length)];
      if (next != _currentLabel) {
        setState(() => _currentLabel = next);
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedSwitcher(
      duration: AppMotion.short,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(anim), child: child),
      ),
      child: Text(
        _currentLabel,
        key: ValueKey(_currentLabel),
        textAlign: TextAlign.center,
        style: widget.style ??
            theme.textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.primary,
            ),
      ),
    );
  }
}
