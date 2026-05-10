import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../data/models/behavior.dart';
import '../../../providers/behavior_provider.dart';
import '../../../providers/student_provider.dart';
import '../../widgets/app_snackbar.dart';
import 'behavior_screen.dart';

/// Shows a bottom-sheet dialog to quickly record behavior for students.
void showQuickRecordDialog(BuildContext context, WidgetRef ref, int classId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (_) => _QuickRecordSheet(classId: classId),
  );
}

class _QuickRecordSheet extends ConsumerStatefulWidget {
  final int classId;
  const _QuickRecordSheet({required this.classId});

  @override
  ConsumerState<_QuickRecordSheet> createState() => _QuickRecordSheetState();
}

class _QuickRecordSheetState extends ConsumerState<_QuickRecordSheet> {
  final Set<int> _selectedStudents = {};
  BehaviorCategory? _selectedCategory;
  final _noteCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedStudents.isEmpty || _selectedCategory == null) return;
    setState(() => _submitting = true);
    try {
      await ref.read(behaviorRecordsProvider(widget.classId).notifier).addRecords(
            studentIds: _selectedStudents.toList(),
            categoryId: _selectedCategory!.id,
            note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          );
      ref.read(behaviorLeaderboardProvider(widget.classId).notifier).load();
      if (mounted) {
        Navigator.pop(context);
        AppSnackbar.success(context,
            message: '已为 ${_selectedStudents.length} 名学生记录「${_selectedCategory!.name}」');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, message: '记录失败：$e');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final students = ref.watch(studentListProvider(widget.classId));
    final categories = ref.watch(behaviorCategoriesProvider(widget.classId));

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  children: [
                    Text('快速记录',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    FilledButton(
                      onPressed: (_selectedStudents.isEmpty || _selectedCategory == null || _submitting)
                          ? null
                          : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('确认'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // ─── Category picker ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('选择类别',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant)),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 44,
                child: categories.when(
                  loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  error: (e, _) => Text('$e'),
                  data: (cats) => ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    itemCount: cats.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      final cat = cats[i];
                      final selected = _selectedCategory?.id == cat.id;
                      final color = cat.isPositive ? Colors.green.shade600 : scheme.error;
                      return FilterChip(
                        selected: selected,
                        avatar: Icon(behaviorIconData(cat.icon), size: 16, color: selected ? scheme.onPrimary : color),
                        label: Text('${cat.name} (${cat.score > 0 ? '+' : ''}${cat.score.toStringAsFixed(0)})'),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected ? scheme.onPrimary : scheme.onSurface,
                        ),
                        selectedColor: color,
                        checkmarkColor: scheme.onPrimary,
                        onSelected: (_) => setState(() => _selectedCategory = cat),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // ─── Note ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: TextField(
                  controller: _noteCtrl,
                  decoration: InputDecoration(
                    hintText: '备注（可选）',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: BorderSide(color: scheme.outlineVariant),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // ─── Student picker header ────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  children: [
                    Text('选择学生',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant)),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        students.whenData((list) {
                          setState(() {
                            if (_selectedStudents.length == list.length) {
                              _selectedStudents.clear();
                            } else {
                              _selectedStudents
                                ..clear()
                                ..addAll(list.map((s) => s.id));
                            }
                          });
                        });
                      },
                      child: Text(
                        _selectedStudents.isEmpty ? '全选' : '${_selectedStudents.length}已选',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              // ─── Student grid ─────────────────────────────────────
              Expanded(
                child: students.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                  data: (list) {
                    if (list.isEmpty) {
                      return const Center(child: Text('暂无学生'));
                    }
                    return GridView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 100,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.6,
                      ),
                      itemCount: list.length,
                      itemBuilder: (ctx, i) {
                        final s = list[i];
                        final selected = _selectedStudents.contains(s.id);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (selected) {
                                _selectedStudents.remove(s.id);
                              } else {
                                _selectedStudents.add(s.id);
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: AppMotion.short,
                            curve: AppMotion.standard,
                            decoration: BoxDecoration(
                              color: selected
                                  ? scheme.primary.withValues(alpha: 0.12)
                                  : scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(
                                color: selected ? scheme.primary : scheme.outlineVariant,
                                width: selected ? 2 : 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              s.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                color: selected ? scheme.primary : scheme.onSurface,
                              ),
                            ),
                          ),
                        );
                      },
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
