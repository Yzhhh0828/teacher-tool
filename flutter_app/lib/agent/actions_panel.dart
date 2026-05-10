import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/tokens.dart';
import '../providers/agent_provider.dart';
import '../ui/widgets/app_card.dart';
import '../ui/widgets/shimmer_skeleton.dart';

/// Bottom-sheet style panel showing recent agent write actions with undo.
class AgentActionsPanel extends ConsumerStatefulWidget {
  const AgentActionsPanel({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const AgentActionsPanel(),
    );
  }

  @override
  ConsumerState<AgentActionsPanel> createState() => _AgentActionsPanelState();
}

class _AgentActionsPanelState extends ConsumerState<AgentActionsPanel> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() {
    return ref.read(agentRepositoryProvider).listActions();
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _undo(int id) async {
    try {
      await ref.read(agentRepositoryProvider).undoAction(id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已撤销')));
      }
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  children: [
                    Text('AI 操作记录', style: theme.textTheme.titleLarge),
                    const Spacer(),
                    IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return ShimmerSkeleton.list(itemCount: 3, itemHeight: 64);
                    }
                    if (snap.hasError) {
                      return Center(child: Text('加载失败: ${snap.error}'));
                    }
                    final items = snap.data ?? const [];
                    if (items.isEmpty) {
                      return const Center(child: Text('暂无 AI 写入记录'));
                    }
                    return ListView.separated(
                      controller: scrollController,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (_, i) => _ActionTile(item: items[i], onUndo: _undo),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final void Function(int) onUndo;
  const _ActionTile({required this.item, required this.onUndo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = item['status'] as String? ?? 'committed';
    final diff = (item['diff'] as Map?) ?? const {};
    final summary = _summariseDiff(item['action_type'] as String? ?? '', diff);
    final canUndo = status == 'committed';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(_iconFor(item['action_type'] as String? ?? ''),
                size: 20, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['action_type'] as String? ?? 'unknown',
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(summary,
                    style: theme.textTheme.bodySmall,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                Text(item['created_at'] as String? ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6))),
              ],
            ),
          ),
          if (canUndo)
            TextButton.icon(
              onPressed: () => onUndo(item['id'] as int),
              icon: const Icon(Icons.undo_rounded, size: 18),
              label: const Text('撤销'),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(status, style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }

  static IconData _iconFor(String type) {
    if (type.contains('student')) return Icons.person_add_alt_rounded;
    if (type.contains('grade')) return Icons.assessment_rounded;
    if (type.contains('seat')) return Icons.grid_on_rounded;
    return Icons.bolt_rounded;
  }

  static String _summariseDiff(String type, Map diff) {
    if (diff.isEmpty) return '无变更摘要';
    final parts = <String>[];
    if (diff['created'] != null) parts.add('新增 ${diff['created']}');
    if (diff['updated'] != null) parts.add('更新 ${diff['updated']}');
    if (diff['skipped'] != null) parts.add('跳过 ${diff['skipped']}');
    if (parts.isEmpty) return diff.toString();
    return parts.join(' · ');
  }
}
