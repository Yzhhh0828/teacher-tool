import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../data/models/schedule.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/schedule_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/shimmer_skeleton.dart';

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  static const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final palette = ref.watch(themeProvider).palette;
    final accent = AppAccent(palette).schedule;
    final currentClass = ref.watch(currentClassProvider);
    if (currentClass == null) {
      return Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          title: const Text('课表管理'),
          automaticallyImplyLeading: false,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        body: EmptyView(
          icon: Icons.calendar_view_week_outlined,
          title: '请先选择班级',
          accent: accent,
        ),
      );
    }

    final schedulesAsync =
        ref.watch(scheduleListProvider(currentClass.id));
    final todayWeekday = DateTime.now().weekday - 1;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('课表管理'),
        automaticallyImplyLeading: false,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding:
                const EdgeInsets.only(right: AppSpacing.pagePadding),
            child: FilledButton.icon(
              onPressed: () =>
                  _showAddSheet(context, ref, currentClass.id),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('添加课程'),
            ),
          ),
        ],
      ),
      body: schedulesAsync.when(
        loading: () => ShimmerSkeleton.list(itemCount: 5, itemHeight: 56),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (schedules) {
          if (schedules.isEmpty) {
            return Center(
              child: EmptyView(
                icon: Icons.calendar_view_week_rounded,
                title: '暂无课表',
                message: '点击右上角「添加课程」开始排课',
                accent: accent,
              ),
            );
          }
          final byDay = <int, List<ScheduleModel>>{};
          for (final s in schedules) {
            byDay.putIfAbsent(s.dayOfWeek, () => []).add(s);
          }
          for (final list in byDay.values) {
            list.sort((a, b) => a.period.compareTo(b.period));
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              const gap = 8.0;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.pagePadding),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(7, (day) {
                      final isToday = day == todayWeekday;
                      final daySchedules = byDay[day] ?? [];
                      return Expanded(
                        child: Container(
                          margin: EdgeInsets.only(
                              right: day < 6 ? gap : 0),
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            borderRadius:
                                BorderRadius.circular(AppRadius.m),
                            border: Border.all(
                              color: isToday
                                  ? accent.withValues(alpha: 0.55)
                                  : scheme.outlineVariant,
                              width: isToday ? 1.5 : 1,
                            ),
                            boxShadow: AppShadow.subtle(scheme.shadow),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10),
                                decoration: BoxDecoration(
                                  color: isToday
                                      ? accent.withValues(alpha: 0.12)
                                      : null,
                                  borderRadius:
                                      const BorderRadius.vertical(
                                    top: Radius.circular(
                                        AppRadius.m - 1),
                                  ),
                                ),
                                child: Text(
                                  isToday
                                      ? '${_weekdays[day]}\n今日'
                                      : _weekdays[day],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: isToday
                                        ? accent
                                        : scheme.onSurface,
                                    letterSpacing: -0.1,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.gap2),
                              for (var i = 0;
                                  i < daySchedules.length;
                                  i++)
                                _ScheduleChip(
                                  schedule: daySchedules[i],
                                  accent: accent,
                                  onDelete: () => _deleteSchedule(
                                      context,
                                      ref,
                                      currentClass.id,
                                      daySchedules[i]),
                                )
                                    .animate(
                                        delay: AppMotion.stagger * i)
                                    .fadeIn(duration: AppMotion.short)
                                    .moveY(begin: 4, end: 0),
                              if (daySchedules.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 18),
                                  child: Text(
                                    '空',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.onSurfaceVariant
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: AppSpacing.gap2),
                            ],
                          ),
                        )
                            .animate(delay: AppMotion.stagger * day)
                            .fadeIn(duration: AppMotion.short)
                            .moveY(begin: 8, end: 0),
                      );
                    }),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _deleteSchedule(BuildContext context, WidgetRef ref,
      int classId, ScheduleModel s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除课程'),
        content: Text('确定要删除「${s.subject}」吗？'),
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
    );
    if (confirm == true) {
      try {
        await ref
            .read(scheduleListProvider(classId).notifier)
            .deleteSchedule(s.id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('删除失败：$e')));
        }
      }
    }
  }

  void _showAddSheet(BuildContext context, WidgetRef ref, int classId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddScheduleSheet(classId: classId, ref: ref),
    );
  }
}

class _ScheduleChip extends StatelessWidget {
  final ScheduleModel schedule;
  final Color accent;
  final VoidCallback onDelete;
  const _ScheduleChip({
    required this.schedule,
    required this.accent,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onLongPress: onDelete,
      child: Container(
        margin: const EdgeInsets.fromLTRB(
            AppSpacing.gap2, 0, AppSpacing.gap2, AppSpacing.gap2),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.gap2 + 2, 8, AppSpacing.gap2, 8),
        decoration: AppSurface.tinted(context, accent,
            radius: AppRadius.s, alpha: 0.10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '第${schedule.period}节',
              style: TextStyle(
                fontSize: 10,
                color: accent,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              schedule.subject,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
                height: 1.2,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            if (schedule.classroom?.isNotEmpty == true)
              Text(
                schedule.classroom!,
                style: TextStyle(
                  fontSize: 10,
                  color: scheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}

class _AddScheduleSheet extends StatefulWidget {
  final int classId;
  final WidgetRef ref;
  const _AddScheduleSheet({required this.classId, required this.ref});

  @override
  State<_AddScheduleSheet> createState() => _AddScheduleSheetState();
}

class _AddScheduleSheetState extends State<_AddScheduleSheet> {
  static const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  final _subjectCtrl = TextEditingController();
  final _teacherCtrl = TextEditingController();
  final _classroomCtrl = TextEditingController();
  int _day = 0;
  int _period = 1;
  bool _saving = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _teacherCtrl.dispose();
    _classroomCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(AppSpacing.gap5, AppSpacing.gap5,
          AppSpacing.gap5, AppSpacing.gap5 + bottom),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.l)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('添加课程',
                    style: TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w800)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
                controller: _subjectCtrl,
                decoration: const InputDecoration(
                  labelText: '科目',
                  prefixIcon: Icon(Icons.menu_book_rounded),
                )),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _day,
                    decoration: const InputDecoration(
                      labelText: '星期',
                      prefixIcon: Icon(Icons.calendar_today_rounded),
                    ),
                    items: List.generate(
                        7,
                        (i) => DropdownMenuItem(
                            value: i, child: Text(_weekdays[i]))),
                    onChanged: (v) => setState(() => _day = v!),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _period,
                    decoration: const InputDecoration(
                      labelText: '节次',
                      prefixIcon: Icon(Icons.schedule_rounded),
                    ),
                    items: List.generate(
                        10,
                        (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text('第${i + 1}节'))),
                    onChanged: (v) => setState(() => _period = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
                controller: _teacherCtrl,
                decoration: const InputDecoration(
                  labelText: '教师（选填）',
                  prefixIcon: Icon(Icons.person_rounded),
                )),
            const SizedBox(height: AppSpacing.md),
            TextField(
                controller: _classroomCtrl,
                decoration: const InputDecoration(
                  labelText: '教室（选填）',
                  prefixIcon: Icon(Icons.location_on_rounded),
                )),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                icon: _saving
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onPrimary),
                      )
                    : const Icon(Icons.save_rounded, size: 16),
                label: const Text('保存课程'),
                onPressed: _saving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_subjectCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入科目')));
      return;
    }
    setState(() => _saving = true);
    final schedule = ScheduleModel(
      id: 0,
      classId: widget.classId,
      dayOfWeek: _day,
      period: _period,
      subject: _subjectCtrl.text.trim(),
      teacherName: _teacherCtrl.text.trim().isEmpty
          ? null
          : _teacherCtrl.text.trim(),
      classroom: _classroomCtrl.text.trim().isEmpty
          ? null
          : _classroomCtrl.text.trim(),
    );
    try {
      await widget.ref
          .read(scheduleListProvider(widget.classId).notifier)
          .createSchedule(schedule);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('创建失败：$e')));
      }
    }
  }
}
