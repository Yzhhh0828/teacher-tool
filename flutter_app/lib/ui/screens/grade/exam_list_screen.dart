import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../data/models/grade.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/grade_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/page_transitions.dart';
import '../../widgets/shimmer_skeleton.dart';
import '../../widgets/soft_card.dart';
import 'grade_entry_screen.dart';

class ExamListScreen extends ConsumerWidget {
  const ExamListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final palette = ref.watch(themeProvider).palette;
    final accent = AppAccent(palette).exam;
    final currentClass = ref.watch(currentClassProvider);
    if (currentClass == null) {
      return Scaffold(
        backgroundColor: scheme.surface,
        body: EmptyView(
          icon: Icons.assignment_outlined,
          title: '请先选择班级',
          accent: accent,
        ),
      );
    }

    final examsAsync = ref.watch(examListProvider(currentClass.id));

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('考试管理'),
        automaticallyImplyLeading: false,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding:
                const EdgeInsets.only(right: AppSpacing.pagePadding),
            child: FilledButton.icon(
              onPressed: () =>
                  _showCreateExamDialog(context, ref, currentClass.id),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('创建考试'),
            ),
          ),
        ],
      ),
      body: examsAsync.when(
        loading: () => ShimmerSkeleton.list(itemCount: 4, itemHeight: 88),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (exams) => exams.isEmpty
            ? Center(child: _buildEmpty(context, accent))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pagePadding,
                    AppSpacing.gap4,
                    AppSpacing.pagePadding,
                    AppSpacing.gap6),
                itemCount: exams.length,
                itemBuilder: (context, index) {
                  final exam = exams[index];
                  return _ExamCard(
                    exam: exam,
                    accent: accent,
                    onTap: () => pushSharedAxis(
                        context, (_) => GradeEntryScreen(exam: exam)),
                    onDelete: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('确认删除'),
                          content:
                              Text('确定要删除考试「${exam.name}」吗？'),
                          actions: [
                            TextButton(
                                onPressed: () =>
                                    Navigator.pop(ctx, false),
                                child: const Text('取消')),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: scheme.error,
                              ),
                              onPressed: () =>
                                  Navigator.pop(ctx, true),
                              child: const Text('删除'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref
                            .read(examListProvider(currentClass.id)
                                .notifier)
                            .deleteExam(exam.id);
                      }
                    },
                  )
                      .animate(delay: AppMotion.stagger * index)
                      .fadeIn(duration: AppMotion.short)
                      .moveY(
                        begin: 8,
                        end: 0,
                        duration: AppMotion.short,
                        curve: AppMotion.standard,
                      );
                },
              ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, Color accent) {
    return EmptyView(
      icon: Icons.assignment_rounded,
      title: '暂无考试',
      message: '点击右上角「创建考试」开始记录成绩',
      accent: accent,
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  void _showCreateExamDialog(
      BuildContext context, WidgetRef ref, int classId) {
    final nameController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('创建考试'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '考试名称',
                  prefixIcon: Icon(Icons.assignment_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (date != null) {
                    setState(() => selectedDate = date);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 18,
                          color: Theme.of(context)
                              .colorScheme
                              .primary),
                      const SizedBox(width: AppSpacing.md),
                      Text('考试日期：${_formatDate(selectedDate)}'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed:
                  isLoading ? null : () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (nameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请输入考试名称')),
                        );
                        return;
                      }
                      setState(() => isLoading = true);
                      final exam = Exam(
                        id: 0,
                        classId: classId,
                        name: nameController.text.trim(),
                        date: selectedDate,
                        createdAt: DateTime.now(),
                      );
                      try {
                        await ref
                            .read(examListProvider(classId).notifier)
                            .addExam(exam);
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('操作失败：$e')),
                          );
                        }
                      } finally {
                        if (context.mounted) {
                          setState(() => isLoading = false);
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('创建'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  final Exam exam;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ExamCard({
    required this.exam,
    required this.accent,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final daysSinceExam = DateTime.now().difference(exam.date).inDays;
    final isRecent = daysSinceExam >= 0 && daysSinceExam <= 7;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.gap3),
      child: SoftCard(
        accent: accent,
        onTap: onTap,
        padding: EdgeInsets.zero,
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Color accent strip
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.m),
                    bottomLeft: Radius.circular(AppRadius.m),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.gap3),
              // Icon with ring
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: 0.4), width: 2.5),
                  color: accent.withValues(alpha: 0.08),
                ),
                child: Icon(Icons.assignment_rounded, color: accent, size: 20),
              ),
              const SizedBox(width: AppSpacing.gap3),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.gap3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        exam.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: scheme.onSurface,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 12, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(exam.date),
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (isRecent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.12),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text(
                                '最近',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: accent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Trailing action
              IconButton(
                icon: Icon(Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant),
                onPressed: onTap,
                tooltip: '查看详情',
              ),
              PopupMenuButton<String>(
                tooltip: '更多',
                icon: Icon(Icons.more_vert_rounded,
                    size: 20, color: scheme.onSurfaceVariant),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('删除'),
                      ],
                    ),
                  ),
                ],
                onSelected: (v) {
                  if (v == 'delete') onDelete();
                },
              ),
              const SizedBox(width: AppSpacing.gap1),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
