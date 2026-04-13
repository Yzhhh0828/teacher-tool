import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../agent/chat_screen.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/class_provider.dart';
import '../class_/class_list_screen.dart';
import '../grade/exam_list_screen.dart';
import '../presentation/presentation_screen.dart';
import '../schedule/schedule_screen.dart';
import '../seating/seating_screen.dart';
import '../student/student_list_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final currentClass = ref.watch(currentClassProvider);
    final classesAsync = ref.watch(classListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('教师工作台'),
        actions: [
          IconButton(
            tooltip: '退出登录',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authStateProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(classListProvider.notifier).loadClasses(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _OverviewCard(
              title: authState.user?.phone ?? '未识别账号',
              subtitle: currentClass == null
                  ? '当前还没有选中的班级，先去班级列表选择一个班级。'
                  : '当前班级：${currentClass.name} · ${currentClass.grade}',
              trailing: classesAsync.when(
                loading: () => const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, __) => const Icon(Icons.error_outline),
                data: (classes) => Text(
                  '${classes.length} 个班级',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _QuickActionCard(
                  icon: Icons.groups_rounded,
                  title: '班级管理',
                  subtitle: '创建、加入和切换班级',
                  onTap: () => _openPage(context, const ClassListScreen()),
                ),
                _QuickActionCard(
                  icon: Icons.badge_outlined,
                  title: '学生管理',
                  subtitle: '查看和编辑班级学生',
                  onTap: () => _openPage(context, const StudentListScreen()),
                ),
                _QuickActionCard(
                  icon: Icons.assignment_outlined,
                  title: '考试成绩',
                  subtitle: '录入考试并维护成绩',
                  onTap: () => _openPage(context, const ExamListScreen()),
                ),
                _QuickActionCard(
                  icon: Icons.grid_view_rounded,
                  title: '座位管理',
                  subtitle: '创建和调整座位表',
                  onTap: () => _openPage(context, const SeatingScreen()),
                ),
                _QuickActionCard(
                  icon: Icons.calendar_view_week_outlined,
                  title: '课表管理',
                  subtitle: '维护班级课程安排',
                  onTap: () => _openPage(context, const ScheduleScreen()),
                ),
                _QuickActionCard(
                  icon: Icons.present_to_all_rounded,
                  title: '课堂展示',
                  subtitle: '随机点名与课堂工具',
                  onTap: () => _openPage(context, const PresentationScreen()),
                ),
                _QuickActionCard(
                  icon: Icons.smart_toy_outlined,
                  title: 'AI 助手',
                  subtitle: '与教学助手对话',
                  onTap: () => _openPage(context, const ChatScreen()),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              '使用建议',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentClass == null
                          ? '先进入“班级管理”创建或选择班级，再继续后续操作。'
                          : '你已经选择了 ${currentClass.name}，可以直接进入学生、考试和座位模块。',
                    ),
                    const SizedBox(height: 8),
                    const Text('如果接口地址不是本机，请通过 `--dart-define=API_BASE_URL=...` 指定后端地址。'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPage(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget trailing;

  const _OverviewCard({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.school_outlined,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(subtitle),
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 12),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(subtitle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
