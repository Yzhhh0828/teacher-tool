import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../agent/chat_screen.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/class_provider.dart';
import '../../../core/theme/app_theme.dart';
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
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 600 ? 3 : 2;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: RefreshIndicator(
        color: AppTheme.primaryColor,
        onRefresh: () => ref.read(classListProvider.notifier).loadClasses(),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 120.0,
              floating: false,
              pinned: true,
              backgroundColor: AppTheme.backgroundLight,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
                title: Text(
                  '教师工作台',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceWhite,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.logout_rounded, color: AppTheme.primaryDark, size: 20),
                    ),
                    tooltip: '退出登录',
                    onPressed: () async {
                      await ref.read(authStateProvider.notifier).logout();
                    },
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: _OverviewCard(
                  title: authState.user?.phone ?? '未识别账号',
                  subtitle: currentClass == null
                      ? '当前还没有选中的班级，先去班级列表选择一个班级。'
                      : '当前班级：${currentClass.name} · ${currentClass.grade}',
                  trailingIcon: Icons.auto_awesome,
                  classCountWidget: classesAsync.when(
                    loading: () => const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                    error: (_, __) => const Icon(Icons.error_outline, color: Colors.white),
                    data: (classes) => Text(
                      '${classes.length} 个班级',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              sliver: SliverToBoxAdapter(
                child: Text(
                  '快捷操作',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.15,
                ),
                delegate: SliverChildListDelegate.fixed([
                  _ActionTile(
                    icon: Icons.groups_rounded,
                    title: '班级管理',
                    color: AppTheme.primaryColor,
                    onTap: () => _openPage(context, const ClassListScreen()),
                  ),
                  _ActionTile(
                    icon: Icons.badge_outlined,
                    title: '学生管理',
                    color: AppTheme.primaryDark,
                    onTap: () => _openPage(context, const StudentListScreen()),
                  ),
                  _ActionTile(
                    icon: Icons.assignment_outlined,
                    title: '考试成绩',
                    color: const Color(0xFFB8956A),
                    onTap: () => _openPage(context, const ExamListScreen()),
                  ),
                  _ActionTile(
                    icon: Icons.grid_view_rounded,
                    title: '座位管理',
                    color: AppTheme.successColor,
                    onTap: () => _openPage(context, const SeatingScreen()),
                  ),
                  _ActionTile(
                    icon: Icons.calendar_view_week_outlined,
                    title: '课表管理',
                    color: const Color(0xFF8E7B6B),
                    onTap: () => _openPage(context, const ScheduleScreen()),
                  ),
                  _ActionTile(
                    icon: Icons.present_to_all_rounded,
                    title: '课堂展示',
                    color: AppTheme.accent,
                    onTap: () => _openPage(context, const PresentationScreen()),
                  ),
                  _ActionTile(
                    icon: Icons.smart_toy_outlined,
                    title: 'AI 助手',
                    color: const Color(0xFF9E8678),
                    onTap: () => _openPage(context, const ChatScreen()),
                  ),
                ]),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 48)),
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
  final IconData trailingIcon;
  final Widget classCountWidget;

  const _OverviewCard({
    required this.title,
    required this.subtitle,
    required this.trailingIcon,
    required this.classCountWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              trailingIcon,
              size: 100,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: classCountWidget,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceWhite,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
