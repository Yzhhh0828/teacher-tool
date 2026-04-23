import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/schedule_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../class_/class_detail_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final currentClass = ref.watch(currentClassProvider);
    final classesAsync = ref.watch(classListProvider);

    final now = DateTime.now();
    final greeting = now.hour < 12 ? '早上好' : now.hour < 18 ? '下午好' : '晚上好';
    final phone = authState.user?.phone ?? '';
    final displayName = phone.length >= 4 ? phone.substring(phone.length - 4) : phone;

    final todaySchedulesAsync = currentClass != null
        ? ref.watch(scheduleListProvider(currentClass.id))
        : null;
    final todayWeekday = now.weekday - 1;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: RefreshIndicator(
        color: AppTheme.primaryColor,
        onRefresh: () => ref.read(classListProvider.notifier).loadClasses(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting，$displayName',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(now),
                      style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            // Stats row
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: classesAsync.when(
                  loading: () => const SizedBox(height: 72, child: Center(child: CircularProgressIndicator())),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (classes) => Row(
                    children: [
                      _StatChip(
                        label: '${classes.length}',
                        sublabel: '个班级',
                        icon: Icons.school_outlined,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 12),
                      if (currentClass != null) ...[
                        Consumer(builder: (ctx, r, _) {
                          final students = r.watch(studentListProvider(currentClass.id));
                          return students.when(
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                            data: (list) => _StatChip(
                              label: '${list.length}',
                              sublabel: '名学生',
                              icon: Icons.people_outline,
                              color: AppTheme.accent,
                            ),
                          );
                        }),
                        const SizedBox(width: 12),
                        if (todaySchedulesAsync != null)
                          Consumer(builder: (ctx, r, _) {
                            final schedules = r.watch(scheduleListProvider(currentClass.id));
                            return schedules.when(
                              loading: () => const SizedBox.shrink(),
                              error: (_, __) => const SizedBox.shrink(),
                              data: (list) {
                                final todayCount = list.where((s) => s.dayOfWeek == todayWeekday).length;
                                return _StatChip(
                                  label: '$todayCount',
                                  sublabel: '节课今天',
                                  icon: Icons.today_outlined,
                                  color: AppTheme.successColor,
                                );
                              },
                            );
                          }),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            // Current class card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: classesAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (classes) {
                    if (classes.isEmpty) {
                      return _EmptyClassCard(onTap: () {});
                    }
                    final cls = currentClass ?? classes.first;
                    if (currentClass == null) {
                      Future.microtask(() => ref.read(currentClassProvider.notifier).state = classes.first);
                    }
                    return _CurrentClassCard(
                      className: cls.name,
                      grade: cls.grade,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ClassDetailScreen(classId: cls.id)),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            // Today's schedule
            if (currentClass != null && todaySchedulesAsync != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '今日课程',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              _weekdays[todayWeekday],
                              style: const TextStyle(fontSize: 13, color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Consumer(builder: (ctx, r, _) {
                        final schedules = r.watch(scheduleListProvider(currentClass.id));
                        return schedules.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (list) {
                            final today = list.where((s) => s.dayOfWeek == todayWeekday).toList()
                              ..sort((a, b) => a.period.compareTo(b.period));
                            if (today.isEmpty) {
                              return _EmptyState(
                                icon: Icons.wb_sunny_outlined,
                                message: '今天没有课程，好好休息',
                                small: true,
                              );
                            }
                            return Column(
                              children: today.map((s) => _ScheduleRow(schedule: s)).toList(),
                            );
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = ['一', '二', '三', '四', '五', '六', '七', '八', '九', '十', '十一', '十二'];
    const days = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${d.year} 年 ${months[d.month - 1]} 月 ${d.day} 日  ${days[d.weekday - 1]}';
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final Color color;
  const _StatChip({required this.label, required this.sublabel, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: color)),
          const SizedBox(width: 4),
          Text(sublabel, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _CurrentClassCard extends StatelessWidget {
  final String className;
  final String grade;
  final VoidCallback onTap;
  const _CurrentClassCard({required this.className, required this.grade, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.primaryColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.school_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      className,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$grade年级  ·  点击查看详情',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyClassCard extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyClassCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        children: [
          Icon(Icons.school_outlined, size: 36, color: AppTheme.textSecondary.withOpacity(0.4)),
          const SizedBox(height: 8),
          Text('还没有班级', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text('前往「班级」标签创建你的第一个班级',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  final dynamic schedule;
  const _ScheduleRow({required this.schedule});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
              child: Text(
                '${schedule.period}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primaryColor),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              schedule.subject,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textPrimary),
            ),
          ),
          if (schedule.classroom?.isNotEmpty == true)
            Text(
              schedule.classroom!,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool small;
  const _EmptyState({required this.icon, required this.message, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: small ? 16 : 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: small ? 32 : 48, color: AppTheme.textSecondary.withOpacity(0.3)),
          const SizedBox(height: 8),
          Text(message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
