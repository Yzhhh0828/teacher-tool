import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../data/models/grade.dart';
import '../../../data/models/student.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/grade_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../widgets/confetti_button.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/shimmer_skeleton.dart';
import '../../widgets/soft_card.dart';

class GradeEntryScreen extends ConsumerStatefulWidget {
  final Exam exam;
  const GradeEntryScreen({super.key, required this.exam});

  @override
  ConsumerState<GradeEntryScreen> createState() =>
      _GradeEntryScreenState();
}

class _GradeEntryScreenState
    extends ConsumerState<GradeEntryScreen> {
  final Map<int, TextEditingController> _scoreCtrls = {};
  final Map<int, TextEditingController> _remarksCtrls = {};
  String _selectedSubject = '语文';

  static const _subjects = [
    '语文', '数学', '英语', '物理', '化学', '生物', '历史', '地理', '政治',
  ];

  @override
  void dispose() {
    for (final c in _scoreCtrls.values) {
      c.dispose();
    }
    for (final c in _remarksCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

    final studentsAsync =
        ref.watch(studentListProvider(currentClass.id));
    final gradesAsync = ref.watch(examGradesProvider(widget.exam.id));

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text('${widget.exam.name} · 录入成绩'),
        actions: [
          IconButton(
            tooltip: '一键保存全部',
            icon: const Icon(Icons.save_alt_rounded),
            onPressed: () => _saveAll(),
          ),
          const SizedBox(width: AppSpacing.gap2),
        ],
      ),
      body: Column(
        children: [
          // Subject chips
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.pagePadding,
                AppSpacing.gap4,
                AppSpacing.pagePadding,
                AppSpacing.gap2),
            child: SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _subjects.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.gap2),
                itemBuilder: (_, i) {
                  final subject = _subjects[i];
                  final selected = subject == _selectedSubject;
                  return ChoiceChip(
                    label: Text(subject),
                    selected: selected,
                    onSelected: (_) => setState(
                        () => _selectedSubject = subject),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pagePadding),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.gap3),
              decoration: AppSurface.tinted(context, accent,
                  radius: AppRadius.m, alpha: 0.10),
              child: Row(
                children: [
                  Icon(Icons.tips_and_updates_rounded,
                      color: accent, size: 18),
                  const SizedBox(width: AppSpacing.gap2),
                  Expanded(
                    child: Text(
                      '当前科目：$_selectedSubject · 输入分数后按 Tab 自动跳到下一位',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.gap2),
          Expanded(
            child: studentsAsync.when(
              loading: () => ShimmerSkeleton.list(itemCount: 5, itemHeight: 64),
              error: (e, _) => Center(child: Text('加载失败：$e')),
              data: (students) {
                if (students.isEmpty) {
                  return EmptyView(
                    icon: Icons.people_outline,
                    title: '暂无学生',
                    accent: accent,
                  );
                }
                return gradesAsync.when(
                  loading: () => ShimmerSkeleton.list(itemCount: 5, itemHeight: 64),
                  error: (e, _) => Center(child: Text('加载失败：$e')),
                  data: (grades) => _buildList(students, grades, accent),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
      List<Student> students, List<Grade> grades, Color accent) {
    final gradeMap = {for (var g in grades) g.studentId: g};
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          AppSpacing.gap2,
          AppSpacing.pagePadding,
          AppSpacing.gap6),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final s = students[index];
        final existing = gradeMap[s.id];
        _scoreCtrls.putIfAbsent(
          s.id,
          () => TextEditingController(
              text: existing?.score.toString() ?? ''),
        );
        _remarksCtrls.putIfAbsent(
          s.id,
          () => TextEditingController(text: existing?.remarks ?? ''),
        );
        return _GradeRow(
          student: s,
          accent: accent,
          score: _scoreCtrls[s.id]!,
          remarks: _remarksCtrls[s.id]!,
          onSave: () => _saveGrade(s.id, silent: false),
        )
            .animate(delay: AppMotion.stagger * index)
            .fadeIn(duration: AppMotion.short)
            .moveX(begin: -6, end: 0);
      },
    );
  }

  Future<void> _saveGrade(int studentId,
      {required bool silent}) async {
    final scoreText = _scoreCtrls[studentId]?.text.trim() ?? '';
    final remarks = _remarksCtrls[studentId]?.text.trim();
    if (scoreText.isEmpty) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请输入分数')));
      }
      return;
    }
    final score = double.tryParse(scoreText);
    if (score == null) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请输入有效分数')));
      }
      return;
    }
    final grade = Grade(
      id: 0,
      examId: widget.exam.id,
      studentId: studentId,
      subject: _selectedSubject,
      score: score,
      remarks: remarks?.isEmpty == true ? null : remarks,
      createdAt: DateTime.now(),
    );
    try {
      await ref
          .read(examGradesProvider(widget.exam.id).notifier)
          .saveGrade(grade);
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存成功')),
        );
      }
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$e')));
      }
    }
  }

  Future<void> _saveAll() async {
    int saved = 0;
    for (final id in _scoreCtrls.keys) {
      final t = _scoreCtrls[id]?.text.trim() ?? '';
      if (t.isEmpty) continue;
      await _saveGrade(id, silent: true);
      saved++;
    }
    if (mounted) {
      // ignore: unawaited_futures
      ConfettiAction.celebrate(context, message: '已保存 $saved 条成绩');
    }
  }
}

class _GradeRow extends StatelessWidget {
  final Student student;
  final Color accent;
  final TextEditingController score;
  final TextEditingController remarks;
  final VoidCallback onSave;

  const _GradeRow({
    required this.student,
    required this.accent,
    required this.score,
    required this.remarks,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final initial =
        student.name.trim().isEmpty ? '生' : student.name.substring(0, 1);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.gap2),
      child: SoftCard(
        padding: const EdgeInsets.all(AppSpacing.gap4),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: AppGradient.accent(accent, brightness),
                    borderRadius: BorderRadius.circular(AppRadius.s),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.gap3),
                Expanded(
                  child: Text(
                    student.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.save_rounded, size: 14),
                  label: const Text('保存'),
                  onPressed: onSave,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.gap3, vertical: 6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.gap3),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: score,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '分数',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.gap3),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: remarks,
                    decoration: const InputDecoration(
                      labelText: '备注',
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
