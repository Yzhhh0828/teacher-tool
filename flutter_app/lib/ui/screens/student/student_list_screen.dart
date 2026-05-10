import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../data/models/student.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/icon_chip.dart';
import '../../widgets/page_transitions.dart';
import '../../widgets/shimmer_skeleton.dart';
import '../../widgets/soft_card.dart';
import 'student_form_screen.dart';

class StudentListScreen extends ConsumerStatefulWidget {
  const StudentListScreen({super.key});

  @override
  ConsumerState<StudentListScreen> createState() =>
      _StudentListScreenState();
}

class _StudentListScreenState extends ConsumerState<StudentListScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = ref.watch(themeProvider).palette;
    final accent = AppAccent(palette);
    final currentClass = ref.watch(currentClassProvider);

    if (currentClass == null) {
      return Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
        title: const Text('学生管理'),
        automaticallyImplyLeading: false,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
        body: EmptyView(
          icon: Icons.people_outline,
          title: '请先选择班级',
          message: '前往「班级」标签选择一个班级再来吧',
          accent: accent.student,
        ),
      );
    }

    final studentsAsync =
        ref.watch(studentListProvider(currentClass.id));

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(currentClass.name),
        automaticallyImplyLeading: false,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding:
                const EdgeInsets.only(right: AppSpacing.pagePadding),
            child: FilledButton.icon(
              onPressed: () =>
                  _showStudentSheet(context, currentClass.id, null),
              icon: const Icon(Icons.person_add_rounded, size: 16),
              label: const Text('添加学生'),
            ),
          ),
        ],
      ),
      body: studentsAsync.when(
        loading: () => ShimmerSkeleton.list(itemCount: 6, itemHeight: 68),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (students) {
          final filtered = _search.isEmpty
              ? students
              : students
                  .where((s) => s.name.contains(_search))
                  .toList();
          final maleCount =
              students.where((s) => s.gender == 'male').length;
          final femaleCount = students.length - maleCount;

          return Column(
            children: [
              // Stats banner — three plain SoftCards (no rainbow gradient).
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pagePadding,
                    AppSpacing.gap3,
                    AppSpacing.pagePadding,
                    AppSpacing.gap2),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        label: '总人数',
                        value: '${students.length}',
                        icon: Icons.people_alt_rounded,
                        accent: accent.student,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.gap3),
                    Expanded(
                      child: _StatTile(
                        label: '男生',
                        value: '$maleCount',
                        icon: Icons.male_rounded,
                        accent: palette.tertiary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.gap3),
                    Expanded(
                      child: _StatTile(
                        label: '女生',
                        value: '$femaleCount',
                        icon: Icons.female_rounded,
                        accent: palette.accent1,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pagePadding,
                    vertical: AppSpacing.gap2),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: '搜索学生姓名…',
                    prefixIcon: Icon(Icons.search_rounded,
                        color: scheme.onSurfaceVariant),
                    isDense: true,
                  ),
                ),
              ),
              if (students.isEmpty)
                Expanded(
                  child: EmptyView(
                    icon: Icons.people_outline,
                    title: '暂无学生',
                    message: '点击右上角「添加学生」开始建立花名册',
                    accent: accent.student,
                  ),
                )
              else if (filtered.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      '未找到「$_search」',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pagePadding,
                        AppSpacing.gap2,
                        AppSpacing.pagePadding,
                        AppSpacing.gap6),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.gap2),
                    itemBuilder: (context, index) {
                      final student = filtered[index];
                      return Dismissible(
                        key: ValueKey(student.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(
                              right: AppSpacing.gap5),
                          decoration: BoxDecoration(
                            color: scheme.errorContainer,
                            borderRadius:
                                BorderRadius.circular(AppRadius.m),
                          ),
                          child: Icon(Icons.delete_outline_rounded,
                              color: scheme.error),
                        ),
                        confirmDismiss: (_) =>
                            _confirmDelete(context, student.name),
                        onDismissed: (_) async {
                          await ref
                              .read(studentListProvider(
                                      currentClass.id)
                                  .notifier)
                              .deleteStudent(student.id);
                        },
                        child: _StudentTile(
                          student: student,
                          accent: accent.student,
                          onTap: () => pushSharedAxis(
                              context,
                              (_) => StudentFormScreen(
                                    classId: currentClass.id,
                                    student: student,
                                  )),
                        )
                            .animate(delay: AppMotion.stagger * index)
                            .fadeIn(duration: AppMotion.short)
                            .moveX(begin: -6, end: 0),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, String name) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('删除学生'),
            content: Text('确定要删除「$name」吗？'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('取消')),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).colorScheme.error),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showStudentSheet(
      BuildContext context, int classId, Student? student) {
    final nameCtrl = TextEditingController(text: student?.name);
    String gender = student?.gender ?? 'male';
    final isEdit = student != null;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) => Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.gap5,
              AppSpacing.gap4,
              AppSpacing.gap5,
              MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.gap5,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isEdit ? '编辑学生' : '添加学生',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '姓名',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    const Text('性别：'),
                    const SizedBox(width: AppSpacing.sm),
                    ChoiceChip(
                      label: const Text('男'),
                      selected: gender == 'male',
                      onSelected: (_) =>
                          setSt(() => gender = 'male'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ChoiceChip(
                      label: const Text('女'),
                      selected: gender == 'female',
                      onSelected: (_) =>
                          setSt(() => gender = 'female'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton.icon(
                        icon: Icon(isEdit
                            ? Icons.save_rounded
                            : Icons.add_rounded,
                            size: 16),
                        label: Text(isEdit ? '保存' : '添加'),
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;
                          try {
                            if (isEdit) {
                              await ref
                                  .read(studentListProvider(classId)
                                      .notifier)
                                  .updateStudent(student.id, {
                                'name': name,
                                'gender': gender,
                              });
                            } else {
                              final newStudent = Student(
                                id: 0,
                                classId: classId,
                                name: name,
                                gender: gender,
                                phone: null,
                                parentPhone: null,
                                remarks: null,
                                createdAt: DateTime.now(),
                              );
                              await ref
                                  .read(studentListProvider(classId)
                                      .notifier)
                                  .addStudent(newStudent);
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            if (ctx.mounted) {
                              AppSnackbar.error(context,
                                  message: '保存失败：$e');
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SoftCard(
      padding: const EdgeInsets.all(AppSpacing.gap3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconChip(icon: icon, accent: accent, size: 32, iconSize: 16),
          const SizedBox(height: AppSpacing.gap2),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
              letterSpacing: -0.3,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  final Student student;
  final Color accent;
  final VoidCallback onTap;

  const _StudentTile({
    required this.student,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final initial =
        student.name.isNotEmpty ? student.name.substring(0, 1) : '?';
    final isMale = student.gender == 'male';
    final genderColor =
        isMale ? scheme.tertiary : Theme.of(context).colorScheme.secondary;

    // Collect info chips from extended fields
    final chips = <Widget>[];
    if (student.studentNo != null) {
      chips.add(_InfoChip(label: student.studentNo!, icon: Icons.badge_rounded));
    }
    if (student.phone != null) {
      chips.add(_InfoChip(label: student.phone!, icon: Icons.phone_rounded));
    }
    if (student.description != null) {
      chips.add(_InfoChip(label: student.description!, icon: Icons.notes_rounded));
    }

    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.gap4, vertical: AppSpacing.gap3),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppGradient.accent(accent, brightness),
              borderRadius: BorderRadius.circular(AppRadius.m),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.gap3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      student.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      isMale
                          ? Icons.male_rounded
                          : Icons.female_rounded,
                      size: 14,
                      color: genderColor,
                    ),
                  ],
                ),
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: chips,
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: scheme.onSurfaceVariant, size: 20),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _InfoChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: scheme.onSurfaceVariant),
          const SizedBox(width: 3),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 100),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
