import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design/tokens.dart';
import '../../../providers/behavior_provider.dart';
import '../../../providers/class_provider.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/shimmer_skeleton.dart';
import 'quick_record_dialog.dart';

/// Icon mapping from backend icon name → Material icon
IconData behaviorIconData(String name) {
  const map = {
    'lightbulb': Icons.lightbulb_outline_rounded,
    'star': Icons.star_rounded,
    'handshake': Icons.handshake_outlined,
    'thumb_up': Icons.thumb_up_alt_rounded,
    'alarm': Icons.alarm_rounded,
    'assignment_late': Icons.assignment_late_rounded,
    'warning': Icons.warning_amber_rounded,
    'remove_circle': Icons.remove_circle_outline_rounded,
    'cleaning_services': Icons.cleaning_services_rounded,
  };
  return map[name] ?? Icons.emoji_events_rounded;
}

class BehaviorScreen extends ConsumerWidget {
  const BehaviorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentClass = ref.watch(currentClassProvider);
    if (currentClass == null) {
      return const Scaffold(
        body: EmptyView(icon: Icons.class_rounded, title: '请先选择班级'),
      );
    }
    final classId = currentClass.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('行为积分'),
        automaticallyImplyLeading: false,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showQuickRecordDialog(context, ref, classId),
        icon: const Icon(Icons.add_rounded),
        label: const Text('记录'),
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(tabs: [
              Tab(text: '积分排行'),
              Tab(text: '最近记录'),
            ]),
            Expanded(
              child: TabBarView(children: [
                _LeaderboardTab(classId: classId),
                _TimelineTab(classId: classId),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Leaderboard Tab ────────────────────────────────────────────────────────

class _LeaderboardTab extends ConsumerWidget {
  final int classId;
  const _LeaderboardTab({required this.classId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(behaviorLeaderboardProvider(classId));
    final scheme = Theme.of(context).colorScheme;

    return board.when(
      loading: () => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ShimmerSkeleton.list(itemCount: 6, itemHeight: 56),
      ),
      error: (e, _) => Center(child: Text('加载失败：$e')),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyView(icon: Icons.leaderboard_rounded, title: '暂无积分数据');
        }
        return RefreshIndicator(
          onRefresh: () => ref.read(behaviorLeaderboardProvider(classId).notifier).load(),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final s = list[i];
              final rank = i + 1;
              final medal = rank <= 3
                  ? [Icons.emoji_events_rounded, Icons.emoji_events_rounded, Icons.emoji_events_rounded][rank - 1]
                  : null;
              final medalColor = rank == 1
                  ? const Color(0xFFFFD700)
                  : rank == 2
                      ? const Color(0xFFC0C0C0)
                      : const Color(0xFFCD7F32);

              return ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: medal != null
                      ? medalColor.withValues(alpha: 0.15)
                      : scheme.surfaceContainerHighest,
                  child: medal != null
                      ? Icon(medal, size: 20, color: medalColor)
                      : Text(
                          '$rank',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                ),
                title: Text(s.studentName, style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s.totalScore >= 0 ? '+${s.totalScore.toStringAsFixed(0)}' : s.totalScore.toStringAsFixed(0),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: s.totalScore >= 0 ? Colors.green.shade600 : scheme.error,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${s.recordCount}次',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(delay: Duration(milliseconds: 40 * i), duration: AppMotion.medium)
                  .moveX(begin: 20, end: 0);
            },
          ),
        );
      },
    );
  }
}

// ─── Timeline Tab ───────────────────────────────────────────────────────────

class _TimelineTab extends ConsumerWidget {
  final int classId;
  const _TimelineTab({required this.classId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(behaviorRecordsProvider(classId));
    final scheme = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('MM/dd HH:mm');

    return records.when(
      loading: () => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ShimmerSkeleton.list(itemCount: 8, itemHeight: 64),
      ),
      error: (e, _) => Center(child: Text('加载失败：$e')),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyView(icon: Icons.timeline_rounded, title: '暂无行为记录');
        }
        return RefreshIndicator(
          onRefresh: () => ref.read(behaviorRecordsProvider(classId).notifier).load(),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final r = list[i];
              final positive = r.score > 0;
              final color = positive ? Colors.green.shade600 : scheme.error;

              return Dismissible(
                key: ValueKey(r.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: scheme.errorContainer,
                  child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
                ),
                onDismissed: (_) {
                  ref.read(behaviorRecordsProvider(classId).notifier).deleteRecord(r.id);
                  ref.read(behaviorLeaderboardProvider(classId).notifier).load();
                },
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: color.withValues(alpha: 0.1),
                    child: Icon(
                      behaviorIconData(r.categoryName ?? 'star'),
                      size: 18,
                      color: color,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(r.studentName ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          positive ? '+${r.score.toStringAsFixed(0)}' : r.score.toStringAsFixed(0),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    [
                      r.categoryName ?? '',
                      if (r.note != null && r.note!.isNotEmpty) r.note!,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    dateFmt.format(r.createdAt.toLocal()),
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
