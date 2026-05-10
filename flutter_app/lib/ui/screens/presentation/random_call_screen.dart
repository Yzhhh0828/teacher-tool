import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../widgets/confetti_button.dart';

class RandomCallScreen extends ConsumerStatefulWidget {
  const RandomCallScreen({super.key});

  @override
  ConsumerState<RandomCallScreen> createState() =>
      _RandomCallScreenState();
}

class _RandomCallScreenState extends ConsumerState<RandomCallScreen> {
  final _rng = Random();
  String _displayName = '点击下方按钮开始';
  bool _spinning = false;
  Timer? _spinTimer;

  @override
  void dispose() {
    _spinTimer?.cancel();
    super.dispose();
  }

  void _spin() {
    final currentClass = ref.read(currentClassProvider);
    if (currentClass == null) return;
    final asyncValue =
        ref.read(studentListProvider(currentClass.id));
    asyncValue.whenData((students) {
      if (students.isEmpty) {
        setState(() => _displayName = '暂无学生');
        return;
      }
      _spinTimer?.cancel();
      setState(() => _spinning = true);
      // Cycle through random names quickly.
      _spinTimer = Timer.periodic(
        const Duration(milliseconds: 70),
        (_) {
          if (!mounted) return;
          setState(() => _displayName =
              students[_rng.nextInt(students.length)].name);
        },
      );
      // Stop after ~1.6s and announce winner.
      Future.delayed(const Duration(milliseconds: 1600), () {
        if (!mounted) return;
        _spinTimer?.cancel();
        final winner = students[_rng.nextInt(students.length)];
        setState(() {
          _displayName = winner.name;
          _spinning = false;
        });
        // ignore: unawaited_futures
        ConfettiAction.celebrate(context, message: '${winner.name}!');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themeProvider).palette;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1410),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('随机点名'),
      ),
      body: Stack(
        children: [
          // Decorative blurred orbs
          Positioned(
            top: -60,
            left: -40,
            child: _Orb(
                color: palette.tertiary.withValues(alpha: 0.45),
                size: 240),
          ),
          Positioned(
            bottom: -80,
            right: -60,
            child: _Orb(
                color: palette.accent1.withValues(alpha: 0.40),
                size: 280),
          ),
          // Subtle grid overlay (chalkboard feel)
          Positioned.fill(
            child: CustomPaint(
              painter: _ChalkGridPainter(
                  color: Colors.white.withValues(alpha: 0.04)),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxxl,
                      vertical: AppSpacing.huge),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        palette.seed.withValues(alpha: 0.15),
                        palette.tertiary.withValues(alpha: 0.18),
                      ],
                    ),
                    borderRadius:
                        BorderRadius.circular(AppRadius.xxl),
                    border: Border.all(
                        color: palette.seed.withValues(alpha: 0.30)),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Text(
                      _displayName,
                      key: ValueKey(_displayName),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 80,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2,
                        height: 1.1,
                        shadows: [
                          Shadow(
                            color: palette.seed.withValues(alpha: 0.85),
                            blurRadius: 26,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.huge),
                FilledButton.icon(
                  onPressed: _spinning ? null : _spin,
                  icon: Icon(
                    _spinning
                        ? Icons.casino_rounded
                        : Icons.shuffle_rounded,
                    size: 22,
                  ),
                  label: Text(_spinning ? '抽取中…' : '随机选择'),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.seed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 56, vertical: 22),
                    textStyle: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppRadius.pill),
                    ),
                    elevation: 8,
                    shadowColor:
                        palette.seed.withValues(alpha: 0.5),
                  ),
                ).animate(
                  onPlay: (c) => _spinning ? c.repeat() : null,
                ).shimmer(
                  duration: const Duration(milliseconds: 1200),
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final Color color;
  final double size;
  const _Orb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

class _ChalkGridPainter extends CustomPainter {
  final Color color;
  _ChalkGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const step = 40.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
