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
      return const Center(child: Text('请先选择班级'));
    }

    final schedulesAsync = ref.watch(scheduleListProvider(currentClass.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('课表管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateScheduleDialog(context, ref, currentClass.id),
          ),
        ],
      ),
      body: schedulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (schedules) => schedules.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_view_week_outlined, size: 64, color: AppTheme.textSecondary.withOpacity(0.4)),
                    const SizedBox(height: 16),
                    Text('暂无课表', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('点击右上角 + 添加课程', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: schedules.length,
                itemBuilder: (context, index) {
                  final schedule = schedules[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                        foregroundColor: AppTheme.primaryColor,
                        child: Text('${schedule.period}'),
                      ),
                      title: Text(schedule.subject),
                      subtitle: Text(
                        '${_weekdays[schedule.dayOfWeek]} 第${schedule.period}节'
                        '${schedule.teacherName?.isNotEmpty == true ? ' · ${schedule.teacherName}' : ''}'
                        '${schedule.classroom?.isNotEmpty == true ? ' · ${schedule.classroom}' : ''}',
                      ),
                      trailing: PopupMenuButton<String>(
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'delete', child: Text('删除')),
                        ],
                        onSelected: (value) async {
                          if (value != 'delete') return;
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('确认删除'),
                              content: Text('确定要删除 ${schedule.subject} 这节课吗？'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('取消'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.errorColor,
                                  ),
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('删除'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            try {
                              await ref
                                  .read(scheduleListProvider(currentClass.id).notifier)
                                  .deleteSchedule(schedule.id);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('删除课表失败：$e')),
                                );
                              }
                            }
                          }
                        },
                      ),
                    ),
                  ),
                  );
                },
              ),
      ),
    );
  }

  void _showCreateScheduleDialog(BuildContext context, WidgetRef ref, int classId) {
    final subjectController = TextEditingController();
    final teacherController = TextEditingController();
    final classroomController = TextEditingController();
    int dayOfWeek = 0;
    int period = 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('添加课表'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(labelText: '科目'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: dayOfWeek,
                  decoration: const InputDecoration(labelText: '星期'),
                  items: List.generate(
                    _weekdays.length,
                    (index) => DropdownMenuItem(
                      value: index,
                      child: Text(_weekdays[index]),
                    ),
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => dayOfWeek = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: period,
                  decoration: const InputDecoration(labelText: '节次'),
                  items: List.generate(
                    10,
                    (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text('第${index + 1}节'),
                    ),
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => period = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: teacherController,
                  decoration: const InputDecoration(labelText: '教师姓名'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: classroomController,
                  decoration: const InputDecoration(labelText: '教室'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (subjectController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入科目')),
                  );
                  return;
                }

                final schedule = ScheduleModel(
                  id: 0,
                  classId: classId,
                  dayOfWeek: dayOfWeek,
                  period: period,
                  subject: subjectController.text.trim(),
                  teacherName: teacherController.text.trim().isEmpty
                      ? null
                      : teacherController.text.trim(),
                  classroom: classroomController.text.trim().isEmpty
                      ? null
                      : classroomController.text.trim(),
                );

                try {
                  await ref
                      .read(scheduleListProvider(classId).notifier)
                      .createSchedule(schedule);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('创建课表失败：$e')),
                    );
                  }
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
