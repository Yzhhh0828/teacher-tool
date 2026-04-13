import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/class_model.dart';
import '../../../providers/class_provider.dart';
import '../grade/exam_list_screen.dart';
import '../presentation/presentation_screen.dart';
import '../schedule/schedule_screen.dart';
import '../seating/seating_screen.dart';
import '../student/student_list_screen.dart';

class ClassDetailScreen extends ConsumerWidget {
  final int classId;

  const ClassDetailScreen({super.key, required this.classId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(classRepositoryProvider);
    final currentClass = ref.watch(currentClassProvider);
    final classFuture = currentClass?.id == classId
        ? Future<ClassModel>.value(currentClass)
        : repository.getClassDetail(classId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('班级详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              try {
                final code = await repository.createInviteCode(classId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('邀请码: $code')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('生成邀请码失败：$e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<ClassModel>(
        future: classFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('加载班级详情失败：${snapshot.error}'),
              ),
            );
          }

          final classInfo = snapshot.data;
          if (classInfo == null) {
            return const Center(child: Text('未找到班级信息'));
          }

          if (currentClass?.id != classInfo.id) {
            Future.microtask(() {
              ref.read(currentClassProvider.notifier).state = classInfo;
            });
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classInfo.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text('班级 ID：${classInfo.id}'),
                      Text('年级：${classInfo.grade}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '班级功能',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _EntryTile(
                icon: Icons.badge_outlined,
                title: '学生管理',
                subtitle: '查看、添加和维护班级学生',
                onTap: () => _openPage(context, const StudentListScreen()),
              ),
              _EntryTile(
                icon: Icons.assignment_outlined,
                title: '考试成绩',
                subtitle: '创建考试并录入成绩',
                onTap: () => _openPage(context, const ExamListScreen()),
              ),
              _EntryTile(
                icon: Icons.grid_view_outlined,
                title: '座位表',
                subtitle: '维护班级座位布局',
                onTap: () => _openPage(context, const SeatingScreen()),
              ),
              _EntryTile(
                icon: Icons.calendar_view_week_outlined,
                title: '课表管理',
                subtitle: '查看并维护班级课表',
                onTap: () => _openPage(context, const ScheduleScreen()),
              ),
              _EntryTile(
                icon: Icons.present_to_all_outlined,
                title: '课堂展示',
                subtitle: '随机点名与课堂展示工具',
                onTap: () => _openPage(context, const PresentationScreen()),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openPage(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _EntryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
