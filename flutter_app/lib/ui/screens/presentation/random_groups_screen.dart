import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/classroom_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/confetti_button.dart';

/// Random group generator. Backed by `/classroom/{id}/groups` so the result
/// is logged for later review on the dashboard.
class RandomGroupsScreen extends ConsumerStatefulWidget {
  const RandomGroupsScreen({super.key});

  @override
  ConsumerState<RandomGroupsScreen> createState() => _RandomGroupsScreenState();
}

class _RandomGroupsScreenState extends ConsumerState<RandomGroupsScreen> {
  int _groupSize = 4;
  int? _groupCount;
  bool _byCount = false;
  bool _loading = false;
  List<List<Map<String, dynamic>>> _groups = [];

  Future<void> _generate() async {
    final currentClass = ref.read(currentClassProvider);
    if (currentClass == null) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(classroomRepositoryProvider);
      final groups = await repo.randomGroups(
        currentClass.id,
        groupSize: _byCount ? null : _groupSize,
        groupCount: _byCount ? _groupCount : null,
      );
      setState(() => _groups = groups);
      if (mounted && groups.isNotEmpty) {
        // ignore: unawaited_futures
        ConfettiAction.celebrate(context,
            message: '已分成 ${groups.length} 组');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = ref.watch(themeProvider).palette;
    return Scaffold(
      appBar: AppBar(title: const Text('随机分组')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('分组方式', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('每组人数')),
                    ButtonSegment(value: true, label: Text('分成 N 组')),
                  ],
                  selected: {_byCount},
                  onSelectionChanged: (s) => setState(() => _byCount = s.first),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (!_byCount)
                  _Stepper(
                    label: '每组人数',
                    value: _groupSize,
                    min: 2,
                    max: 12,
                    onChanged: (v) => setState(() => _groupSize = v),
                  )
                else
                  _Stepper(
                    label: '组数',
                    value: _groupCount ?? 4,
                    min: 2,
                    max: 20,
                    onChanged: (v) => setState(() => _groupCount = v),
                  ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: _loading ? null : _generate,
                  icon: const Icon(Icons.shuffle_rounded),
                  label: Text(_loading ? '正在分组…' : '生成分组'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_groups.isNotEmpty)
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: List.generate(_groups.length, (i) {
                final g = _groups[i];
                final colors = _groupColors(palette, i);
                return SizedBox(
                  width: 240,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: colors,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: AppShadow.tinted(colors.first),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text(
                                '第 ${i + 1} 组',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${g.length} 人',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        ...g.map(
                          (m) => Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                const Icon(Icons.person_rounded,
                                    size: 14, color: Colors.white),
                                const SizedBox(width: 6),
                                Text('${m['name']}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate(delay: Duration(milliseconds: 80 * i))
                      .fadeIn(duration: AppMotion.medium)
                      .moveY(
                          begin: 16,
                          end: 0,
                          duration: AppMotion.medium,
                          curve: AppMotion.spring),
                );
              }),
            ),
        ],
      ),
    );
  }
}

List<Color> _groupColors(AppPalette p, int i) {
  final pairs = [
    [p.seed, p.tertiary],
    [p.secondary, p.accent2],
    [p.accent1, p.accent3],
    [p.tertiary, p.seed],
    [p.accent3, p.accent1],
    [p.accent2, p.secondary],
  ];
  return pairs[i % pairs.length];
}

class _Stepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
        IconButton.filledTonal(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 48,
          child: Center(child: Text('$value', style: theme.textTheme.titleLarge)),
        ),
        IconButton.filledTonal(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
