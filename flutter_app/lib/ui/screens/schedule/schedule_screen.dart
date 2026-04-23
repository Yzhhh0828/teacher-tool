import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/schedule.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/schedule_provider.dart';
import '../../../core/theme/app_theme.dart';

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  static const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentClass = ref.watch(currentClassProvider);
    if (currentClass == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('课表管理')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_view_week_outlined, size: 48, color: AppTheme.textSecondary.withOpacity(0.3)),
              const SizedBox(height: 12),
              const Text('请先在「班级」中选择班级'),
            ],
          ),
        ),
      );
    }

    final schedulesAsync = ref.watch(scheduleListProvider(currentClass.id));
    final todayWeekday = DateTime.now().weekday - 1;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('课表管理'),
        backgroundColor: AppTheme.backgroundLight,
        surfaceTintColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: () => _showAddSheet(context, ref, currentClass.id),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
      body: schedulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (schedules) {
          if (schedules.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_view_week_outlined, size: 56, color: AppTheme.textSecondary.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text('暂无课表', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text('点击右上角「添加」添加课程', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
                ],
              ),
            );
          }
          // Build a map: dayOfWeek → sorted list of schedules
          final Map<int, List<ScheduleModel>> byDay = {};
          for (final s in schedules) {
            byDay.putIfAbsent(s.dayOfWeek, () => []).add(s);
          }
          for (final list in byDay.values) {
            list.sort((a, b) => a.period.compareTo(b.period));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(7, (day) {
                    final isToday = day == todayWeekday;
                    final daySchedules = byDay[day] ?? [];
                    return Container(
                      width: 110,
                      margin: EdgeInsets.only(right: day < 6 ? 8 : 0),
                      decoration: BoxDecoration(
                        color: isToday ? AppTheme.primaryColor.withOpacity(0.05) : AppTheme.surfaceWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isToday ? AppTheme.primaryColor.withOpacity(0.3) : AppTheme.borderLight,
                          width: isToday ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Day header
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isToday ? AppTheme.primaryColor : Colors.transparent,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                            ),
                            child: Text(
                              _weekdays[day],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isToday ? Colors.white : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          ...daySchedules.map((s) => _ScheduleChip(
                                schedule: s,
                                onDelete: () => _deleteSchedule(context, ref, currentClass.id, s),
                              )),
                          if (daySchedules.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text('空', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary.withOpacity(0.4))),
                            ),
                          const SizedBox(height: 6),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteSchedule(BuildContext context, WidgetRef ref, int classId, ScheduleModel s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除课程'),
        content: Text('确定要删除「${s.subject}」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ref.read(scheduleListProvider(classId).notifier).deleteSchedule(s.id);
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败：$e')));
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
  final VoidCallback onDelete;
  const _ScheduleChip({required this.schedule, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onDelete,
      child: Container(
        margin: const EdgeInsets.fromLTRB(6, 0, 6, 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '第${schedule.period}节',
              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              schedule.subject,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryDark),
              overflow: TextOverflow.ellipsis,
            ),
            if (schedule.classroom?.isNotEmpty == true)
              Text(schedule.classroom!, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary), overflow: TextOverflow.ellipsis),
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
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('添加课程', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 14),
            TextField(controller: _subjectCtrl, decoration: const InputDecoration(labelText: '科目 *', isDense: true)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _day,
                    decoration: const InputDecoration(labelText: '星期', isDense: true),
                    items: List.generate(7, (i) => DropdownMenuItem(value: i, child: Text(_weekdays[i]))),
                    onChanged: (v) => setState(() => _day = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _period,
                    decoration: const InputDecoration(labelText: '节次', isDense: true),
                    items: List.generate(10, (i) => DropdownMenuItem(value: i + 1, child: Text('第${i + 1}节'))),
                    onChanged: (v) => setState(() => _period = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(controller: _teacherCtrl, decoration: const InputDecoration(labelText: '教师（选填）', isDense: true)),
            const SizedBox(height: 12),
            TextField(controller: _classroomCtrl, decoration: const InputDecoration(labelText: '教室（选填）', isDense: true)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_subjectCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入科目')));
      return;
    }
    setState(() => _saving = true);
    final schedule = ScheduleModel(
      id: 0,
      classId: widget.classId,
      dayOfWeek: _day,
      period: _period,
      subject: _subjectCtrl.text.trim(),
      teacherName: _teacherCtrl.text.trim().isEmpty ? null : _teacherCtrl.text.trim(),
      classroom: _classroomCtrl.text.trim().isEmpty ? null : _classroomCtrl.text.trim(),
    );
    try {
      await widget.ref.read(scheduleListProvider(widget.classId).notifier).createSchedule(schedule);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('创建失败：$e')));
      }
    }
  }
}
