import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../providers/analytics_provider.dart';
import '../../../providers/class_provider.dart';
import '../../widgets/animated_number.dart';
import '../../widgets/app_card.dart';
import '../../widgets/shimmer_skeleton.dart';

/// Class-level analytics dashboard backed by `/analytics/class/{id}/overview`.
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cls = ref.watch(currentClassProvider);
    if (cls == null) {
      return const Scaffold(body: Center(child: Text('请先选择一个班级')));
    }
    final overview = ref.watch(classOverviewProvider(cls.id));
    final compare = ref.watch(classCompareProvider((classId: cls.id, subject: null)));

    return Scaffold(
      appBar: AppBar(
        title: Text('${cls.name} · 数据看板'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(classOverviewProvider(cls.id));
              ref.invalidate(classCompareProvider((classId: cls.id, subject: null)));
            },
          ),
        ],
      ),
      body: overview.when(
        loading: () => ShimmerSkeleton.list(itemCount: 4, itemHeight: 80),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (data) {
          final lastExam = data['last_exam'] as Map<String, dynamic>?;
          final genderSplit = (data['gender_split'] ?? const {}) as Map;
          final stats = (lastExam?['stats'] ?? const {}) as Map;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _StatRow(
                children: [
                  _StatTile(label: '学生数', value: (data['student_count'] ?? 0) as num),
                  _StatTile(label: '考试次数', value: (data['exam_count'] ?? 0) as num),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _StatRow(
                children: [
                  _StatTile(label: '男生', value: (genderSplit['male'] ?? 0) as num),
                  _StatTile(label: '女生', value: (genderSplit['female'] ?? 0) as num),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (lastExam != null)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('最近一次考试 · ${lastExam['name']}',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.md),
                      ...stats.entries.map((e) {
                        final s = (e.value ?? const {}) as Map;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                          child: Row(
                            children: [
                              SizedBox(width: 80, child: Text('${e.key}', style: theme.textTheme.titleSmall)),
                              Expanded(
                                child: _MeanBar(
                                  mean: ((s['mean'] ?? 0) as num).toDouble(),
                                  max: 100,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text('μ ${s['mean']}  σ ${s['stdev']}',
                                  style: theme.textTheme.bodySmall),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('班级历次考试均分趋势', style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.md),
                    compare.when(
                      loading: () => const SizedBox(
                        height: 80,
                        child: ShimmerSkeleton(height: 80),
                      ),
                      error: (e, _) => Text('加载失败: $e'),
                      data: (c) {
                        final series = (c['series'] ?? const []) as List;
                        if (series.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                            child: Text('暂无足够数据'),
                          );
                        }
                        return SizedBox(
                          height: 140,
                          child: _MiniLineChart(
                            points: series
                                .map<double>((e) => ((e['mean'] ?? 0) as num).toDouble())
                                .toList(),
                            labels: series
                                .map<String>((e) => (e['exam_name'] ?? '') as String)
                                .toList(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final List<Widget> children;
  const _StatRow({required this.children});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.lg),
          Expanded(child: children[i]),
        ]
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final num value;
  const _StatTile({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.xs),
          AnimatedNumber(
            value: value,
            style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _MeanBar extends StatelessWidget {
  final double mean;
  final double max;
  const _MeanBar({required this.mean, required this.max});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = (mean / max).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: ratio),
        duration: AppMotion.medium,
        curve: AppMotion.emphasized,
        builder: (context, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: 10,
          backgroundColor: scheme.surfaceContainerHighest,
          color: scheme.primary,
        ),
      ),
    );
  }
}

/// Tiny pure-Flutter line chart so we don't need an extra dependency.
class _MiniLineChart extends StatelessWidget {
  final List<double> points;
  final List<String> labels;
  const _MiniLineChart({required this.points, required this.labels});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _LinePainter(points, scheme.primary, scheme.surfaceContainerHighest),
      child: const SizedBox.expand(),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> points;
  final Color line;
  final Color grid;
  _LinePainter(this.points, this.line, this.grid);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final maxV = (points.reduce((a, b) => a > b ? a : b)).clamp(1, 200);
    final minV = (points.reduce((a, b) => a < b ? a : b)).clamp(0, maxV - 1);
    final span = (maxV - minV).abs().toDouble().clamp(1, double.infinity);

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final linePaint = Paint()
      ..color = line
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final dotPaint = Paint()..color = line;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = size.width * i / (points.length - 1);
      final y = size.height - ((points[i] - minV) / span) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => old.points != points;
}
