import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../providers/analytics_provider.dart';
import '../../../widgets/empty_view.dart';
import '../../../widgets/shimmer_skeleton.dart';
import '../../../widgets/soft_card.dart';

/// "成绩趋势" card on the home screen — a compact sparkline of the last 3
/// exam averages plus a small distribution radar. Replaces part of the
/// removed quick-actions grid.
class GradeTrendCard extends ConsumerWidget {
  final int classId;
  final Color accent;
  const GradeTrendCard({super.key, required this.classId, required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final compare =
        ref.watch(classCompareProvider((classId: classId, subject: null)));
    return SoftCard(
      padding: const EdgeInsets.all(AppSpacing.gap4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up_rounded, color: accent, size: 20),
              const SizedBox(width: 8),
              Text(
                '成绩趋势',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              compare.maybeWhen(
                data: (d) {
                  final series = (d['series'] as List?) ?? const [];
                  if (series.length < 2) return const SizedBox.shrink();
                  final last = (series.last['mean'] as num?)?.toDouble() ?? 0;
                  final prev =
                      (series[series.length - 2]['mean'] as num?)?.toDouble() ??
                          0;
                  final delta = last - prev;
                  final up = delta >= 0;
                  final color = up ? Colors.green : Colors.red;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        up
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 14,
                        color: color,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        delta.abs().toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gap3),
          compare.when(
            loading: () => const SizedBox(
              height: 110,
              child: ShimmerSkeleton(height: 110),
            ),
            error: (e, _) => SizedBox(
              height: 110,
              child: Center(
                child: Text('加载失败：$e',
                    style: TextStyle(color: scheme.error, fontSize: 12)),
              ),
            ),
            data: (d) {
              final series = (d['series'] as List?) ?? const [];
              if (series.isEmpty) {
                return SizedBox(
                  height: 110,
                  child: EmptyView(
                    icon: Icons.assignment_outlined,
                    title: '还没有考试数据',
                    message: '录入第一次考试看看走势吧',
                    accent: accent,
                  ),
                );
              }
              // Take last 3 exams.
              final tail = series.length > 3
                  ? series.sublist(series.length - 3)
                  : series;
              final means = tail
                  .map((e) => (e['mean'] as num?)?.toDouble() ?? 0)
                  .toList();
              final names =
                  tail.map((e) => (e['exam_name'] ?? '').toString()).toList();
              return SizedBox(
                height: 110,
                child: _Sparkline(
                  values: means,
                  labels: names,
                  accent: accent,
                ),
              );
            },
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: AppMotion.short)
        .moveY(begin: 6, end: 0, duration: AppMotion.short, curve: AppMotion.standard);
  }
}

class _Sparkline extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final Color accent;
  const _Sparkline({
    required this.values,
    required this.labels,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (ctx, t, _) => CustomPaint(
        painter: _SparklinePainter(
          values: values,
          labels: labels,
          color: accent,
          progress: t,
          textColor: Theme.of(ctx).colorScheme.onSurfaceVariant,
        ),
        size: const Size(double.infinity, 110),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color color;
  final double progress;
  final Color textColor;
  _SparklinePainter({
    required this.values,
    required this.labels,
    required this.color,
    required this.progress,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const padX = 16.0;
    const padTop = 12.0;
    const padBottom = 26.0;
    final maxV = math.max(values.reduce(math.max), 100.0);
    final minV = math.min(values.reduce(math.min), 0.0);
    final span = (maxV - minV).abs() < 1 ? 1.0 : (maxV - minV);
    final w = size.width - padX * 2;
    final h = size.height - padTop - padBottom;

    final pts = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = padX +
          (values.length == 1
              ? w / 2
              : w * (i / (values.length - 1)));
      final y = padTop + h - ((values[i] - minV) / span) * h;
      pts.add(Offset(x, y));
    }

    // Animated reveal of the line.
    final cutoff = (pts.length * progress).clamp(0.0, pts.length.toDouble());

    // Filled gradient under the line.
    if (pts.length > 1 && cutoff > 1) {
      final path = Path()..moveTo(pts.first.dx, padTop + h);
      for (var i = 0; i < pts.length; i++) {
        if (i + 1 > cutoff) break;
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      path
        ..lineTo(pts[(cutoff - 1).clamp(0, pts.length - 1).floor()].dx,
            padTop + h)
        ..close();
      final gradPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.30), color.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, padTop, size.width, h));
      canvas.drawPath(path, gradPaint);
    }

    // Line stroke.
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (pts.length > 1) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < pts.length; i++) {
        if (i > cutoff) break;
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      canvas.drawPath(path, linePaint);
    }

    // Dots + value labels.
    final dotPaint = Paint()..color = color;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < pts.length; i++) {
      if (i >= cutoff) break;
      canvas.drawCircle(pts[i], 4.5, Paint()..color = Colors.white);
      canvas.drawCircle(pts[i], 3.0, dotPaint);

      // Value above dot.
      tp.text = TextSpan(
        text: values[i].toStringAsFixed(1),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      );
      tp.layout();
      tp.paint(canvas,
          Offset(pts[i].dx - tp.width / 2, pts[i].dy - tp.height - 6));

      // Exam label below.
      tp.text = TextSpan(
        text: labels[i].length > 6
            ? '${labels[i].substring(0, 6)}…'
            : labels[i],
        style: TextStyle(color: textColor, fontSize: 10),
      );
      tp.layout();
      tp.paint(canvas,
          Offset(pts[i].dx - tp.width / 2, padTop + h + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.values != values ||
      oldDelegate.color != color;
}
