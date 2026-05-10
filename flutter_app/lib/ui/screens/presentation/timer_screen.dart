import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../providers/theme_provider.dart';
import '../../widgets/app_card.dart';

/// Classroom-friendly countdown timer. Pure-client, no backend dependency.
class TimerScreen extends ConsumerStatefulWidget {
  const TimerScreen({super.key});

  @override
  ConsumerState<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends ConsumerState<TimerScreen> {
  Duration _remaining = const Duration(minutes: 5);
  Duration _total = const Duration(minutes: 5);
  Timer? _ticker;
  bool _running = false;

  static const _presets = [
    Duration(minutes: 1),
    Duration(minutes: 3),
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 15),
    Duration(minutes: 30),
  ];

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _setPreset(Duration d) {
    setState(() {
      _total = d;
      _remaining = d;
      _running = false;
      _ticker?.cancel();
    });
  }

  void _toggle() {
    if (_remaining.inMilliseconds <= 0) {
      _setPreset(_total);
    }
    if (_running) {
      _ticker?.cancel();
      setState(() => _running = false);
      return;
    }
    setState(() => _running = true);
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {
        final next = _remaining - const Duration(milliseconds: 100);
        _remaining = next.isNegative ? Duration.zero : next;
        if (_remaining.inMilliseconds == 0) {
          _running = false;
          _ticker?.cancel();
        }
      });
    });
  }

  void _reset() {
    _ticker?.cancel();
    setState(() {
      _remaining = _total;
      _running = false;
    });
  }

  String _format(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = ref.watch(themeProvider).palette;
    final progress = _total.inMilliseconds == 0
        ? 0.0
        : 1.0 - _remaining.inMilliseconds / _total.inMilliseconds;
    final lowTime = _remaining.inSeconds <= 10 && _running;
    final ringColor = lowTime ? scheme.error : palette.seed;

    return Scaffold(
      appBar: AppBar(title: const Text('课堂计时器')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.xl),
            AspectRatio(
              aspectRatio: 1,
              child: AnimatedContainer(
                duration: AppMotion.short,
                curve: AppMotion.standard,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: AppShadow.tinted(ringColor),
                        ),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: progress),
                          duration: AppMotion.short,
                          curve: AppMotion.standard,
                          builder: (context, v, _) =>
                              CircularProgressIndicator(
                            value: v,
                            strokeWidth: 18,
                            backgroundColor:
                                scheme.surfaceContainerHighest,
                            color: ringColor,
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      _format(_remaining),
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontSize: 88,
                        fontWeight: FontWeight.w900,
                        fontFeatures:
                            const [FontFeature.tabularFigures()],
                        color: lowTime ? scheme.error : ringColor,
                        letterSpacing: -2,
                      ),
                    )
                        .animate(
                            target: lowTime ? 1 : 0,
                            onPlay: (c) =>
                                lowTime ? c.repeat(reverse: true) : null)
                        .scale(
                          begin: const Offset(1, 1),
                          end: const Offset(1.06, 1.06),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  iconSize: 32,
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                const SizedBox(width: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: _toggle,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(160, 64),
                    shape: const StadiumBorder(),
                  ),
                  icon: Icon(_running ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 28),
                  label: Text(
                    _running ? '暂停' : '开始',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('快捷预设', style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final d in _presets)
                        ChoiceChip(
                          label: Text('${d.inMinutes} 分钟'),
                          selected: _total == d,
                          onSelected: (_) => _setPreset(d),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
