import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/tokens.dart';
import '../providers/agent_provider.dart';
import '../ui/widgets/app_card.dart';
import '../ui/widgets/shimmer_skeleton.dart';

/// Browseable list of registered agent tools, grouped by category.
class AgentToolsPanel extends ConsumerStatefulWidget {
  const AgentToolsPanel({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const AgentToolsPanel(),
    );
  }

  @override
  ConsumerState<AgentToolsPanel> createState() => _AgentToolsPanelState();
}

class _AgentToolsPanelState extends ConsumerState<AgentToolsPanel> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(agentRepositoryProvider).listTools();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text('可用 AI 工具', style: theme.textTheme.titleLarge),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return ShimmerSkeleton.list(itemCount: 4, itemHeight: 56);
                    }
                    if (snap.hasError) {
                      return Center(child: Text('加载失败: ${snap.error}'));
                    }
                    final items = snap.data ?? const [];
                    final byCat = <String, List<Map<String, dynamic>>>{};
                    for (final t in items) {
                      byCat.putIfAbsent(t['category'] as String? ?? 'misc', () => []).add(t);
                    }
                    final cats = byCat.keys.toList()..sort();
                    return ListView(
                      controller: scrollController,
                      children: [
                        for (final cat in cats) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                            child: Text(_labelFor(cat),
                                style: theme.textTheme.titleSmall?.copyWith(
                                    color: theme.colorScheme.primary)),
                          ),
                          ...byCat[cat]!.map((t) => _ToolTile(tool: t)),
                        ],
                      ],
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

  static String _labelFor(String cat) {
    switch (cat) {
      case 'student':
        return '学生管理';
      case 'grade':
        return '成绩录入';
      case 'seating':
        return '座位编排';
      case 'analytics':
        return '数据分析';
      case 'classroom':
        return '课堂互动';
      case 'vision':
        return '图像录入';
      default:
        return cat;
    }
  }
}

class _ToolTile extends StatelessWidget {
  final Map<String, dynamic> tool;
  const _ToolTile({required this.tool});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final write = tool['requires_confirmation'] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(write ? Icons.edit_note_rounded : Icons.search_rounded,
                size: 20, color: write ? theme.colorScheme.error : theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(tool['name'] as String? ?? '',
                            style: theme.textTheme.titleSmall),
                      ),
                      if (write)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text('需确认',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: theme.colorScheme.onErrorContainer)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(tool['description'] as String? ?? '',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
