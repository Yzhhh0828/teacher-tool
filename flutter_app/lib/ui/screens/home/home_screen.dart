import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../data/models/schedule.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/schedule_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../core/router.dart';
import '../../widgets/animated_counter.dart';
import '../../widgets/class_switcher.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/icon_chip.dart';
import '../../widgets/section_header.dart';
import '../../widgets/shimmer_skeleton.dart';
import '../../widgets/soft_card.dart';
import 'widgets/grade_trend_card.dart';
import 'widgets/mood_quote_card.dart';

/// Class-scoped workspace ("工作台"). The sidebar already shows the current
/// class, so this page focuses on stats + today's agenda + quick jumps to
/// the other tabs (no separate "current class" card, no class-detail page).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final palette = ref.watch(themeProvider).palette;
    final accent = AppAccent(palette);
    final authState = ref.watch(authStateProvider);
    final currentClass = ref.watch(currentClassProvider);

    final now = DateTime.now();
    final greeting = _greeting(now.hour);
    final phone = authState.user?.phone ?? '';
    final shortName = phone.length >= 4
        ? phone.substring(phone.length - 4)
        : phone;
    final todayWeekday = now.weekday - 1;

    if (currentClass == null) {
      return const _EmptyHomeOnboarding();
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      body: RefreshIndicator(
        color: scheme.primary,
        onRefresh: () => ref.read(classListProvider.notifier).loadClasses(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Hero greeting ──
            SliverToBoxAdapter(
              child: _GreetingHero(
                palette: palette,
                greeting: greeting,
                name: shortName,
                date: _formatDate(now),
                className: currentClass.name,
              ),
            ),
            // ── Dashboard overview ──
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pagePadding,
                  AppSpacing.gap5,
                  AppSpacing.pagePadding,
                  0),
              sliver: SliverToBoxAdapter(
                child: _DashboardOverview(
                  classId: currentClass.id,
                  todayWeekday: todayWeekday,
                  accent: accent,
                ),
              ),
            ),
            const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.gap5)),
            // ── Grade trend mini chart ──
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pagePadding),
              sliver: SliverToBoxAdapter(
                child: GradeTrendCard(
                  classId: currentClass.id,
                  accent: accent.exam,
                ),
              ),
            ),
            const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.gap5)),
            // ── Today's schedule ──
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pagePadding,
                  0,
                  AppSpacing.pagePadding,
                  AppSpacing.gap6),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: '今日课程',
                      badge: _weekdays[todayWeekday],
                      badgeColor: accent.schedule,
                      trailing: TextButton(
                        onPressed: () =>
                            context.go(AppRoutes.schedule),
                        child: const Text('查看课表'),
                      ),
                    ),
                    Consumer(builder: (ctx, r, _) {
                      final schedules =
                          r.watch(scheduleListProvider(currentClass.id));
                      return schedules.when(
                        loading: () => Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.gap5),
                          child: ShimmerSkeleton.list(
                              itemCount: 3, itemHeight: 48),
                        ),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (list) {
                          final today = list
                              .where((s) => s.dayOfWeek == todayWeekday)
                              .toList()
                            ..sort((a, b) =>
                                a.period.compareTo(b.period));
                          if (today.isEmpty) {
                            return EmptyView(
                              icon: Icons.wb_sunny_rounded,
                              title: '今天没有课',
                              message: '好好休息，养精蓄锐',
                              accent: accent.schedule,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.gap4,
                                  vertical: AppSpacing.gap5),
                            );
                          }
                          return Column(
                            children: [
                              for (var i = 0; i < today.length; i++)
                                _ScheduleRow(
                                  schedule: today[i],
                                  accent: accent.schedule,
                                )
                                    .animate(
                                        delay: AppMotion.stagger * i)
                                    .fadeIn(duration: AppMotion.short)
                                    .moveX(
                                      begin: -8,
                                      end: 0,
                                      duration: AppMotion.short,
                                      curve: AppMotion.standard,
                                    ),
                            ],
                          );
                        },
                      );
                    }),
                  ],
                ),
              ),
            ),
            // ── Mood + quote card (replaces former quick actions) ──
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pagePadding,
                  0,
                  AppSpacing.pagePadding,
                  AppSpacing.gap6),
              sliver: SliverToBoxAdapter(
                child: MoodQuoteCard(accent: accent.behavior),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _greeting(int hour) {
    if (hour < 6) return '夜深了';
    if (hour < 12) return '早上好';
    if (hour < 14) return '中午好';
    if (hour < 18) return '下午好';
    return '晚上好';
  }

  String _formatDate(DateTime d) {
    const months = [
      '一', '二', '三', '四', '五', '六', '七', '八', '九', '十', '十一', '十二'
    ];
    const days = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${d.year} 年 ${months[d.month - 1]} 月 ${d.day} 日 · ${days[d.weekday - 1]}';
  }
}

// ─── Hero ───────────────────────────────────────────────────────────────────

class _GreetingHero extends StatelessWidget {
  final AppPalette palette;
  final String greeting;
  final String name;
  final String date;
  final String className;
  const _GreetingHero({
    required this.palette,
    required this.greeting,
    required this.name,
    required this.date,
    required this.className,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          AppSpacing.gap4,
          AppSpacing.pagePadding,
          0),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.gap5, AppSpacing.gap5, AppSpacing.gap5, AppSpacing.gap5),
      decoration: BoxDecoration(
        gradient: AppGradient.hero(palette, brightness),
        borderRadius: BorderRadius.circular(AppRadius.l),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            greeting,
            style: TextStyle(
              fontSize: 13.5,
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name.isEmpty ? '老师' : '$name 老师',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.4,
              height: 1.15,
            ),
          )
              .animate()
              .fadeIn(duration: AppMotion.short)
              .moveY(
                begin: 6,
                end: 0,
                duration: AppMotion.short,
                curve: AppMotion.standard,
              ),
          const SizedBox(height: AppSpacing.gap2),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded,
                  size: 13,
                  color: Colors.white.withValues(alpha: 0.78)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '$date · $className',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Dashboard overview (powered by /dashboard/class API) ────────────────

class _DashboardOverview extends ConsumerWidget {
  final int classId;
  final int todayWeekday;
  final AppAccent accent;
  const _DashboardOverview({
    required this.classId,
    required this.todayWeekday,
    required this.accent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(dashboardProvider(classId));
    // Local fallback while API loads
    final students = ref.watch(studentListProvider(classId));
    final schedules = ref.watch(scheduleListProvider(classId));

    final studentCount = dash.maybeWhen(
      data: (d) => d['student_count'] as int? ?? 0,
      orElse: () =>
          students.maybeWhen(data: (l) => l.length, orElse: () => 0),
    );
    final todayCount = schedules.maybeWhen(
      data: (l) => l.where((s) => s.dayOfWeek == todayWeekday).length,
      orElse: () => 0,
    );
    final examCount = dash.maybeWhen(
      data: (d) => d['exam_count'] as int? ?? 0,
      orElse: () => 0,
    );
    final scheduleFill = dash.maybeWhen(
      data: (d) => (d['schedule_fill_rate'] as num?)?.toDouble() ?? 0,
      orElse: () => 0.0,
    );
    final latestExam = dash.maybeWhen(
      data: (d) => d['latest_exam_name'] as String?,
      orElse: () => null,
    );
    final latestAvg = dash.maybeWhen(
      data: (d) => d['latest_exam_avg'] as num?,
      orElse: () => null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.people_alt_rounded,
                value: studentCount,
                label: '学生',
                accent: accent.student,
              ),
            ),
            const SizedBox(width: AppSpacing.gap3),
            Expanded(
              child: _StatCard(
                icon: Icons.today_rounded,
                value: todayCount,
                label: '今日课时',
                accent: accent.schedule,
              ),
            ),
            const SizedBox(width: AppSpacing.gap3),
            Expanded(
              child: _StatCard(
                icon: Icons.assignment_rounded,
                value: examCount,
                label: '考试',
                accent: accent.exam,
              ),
            ),
          ],
        ),
        if (latestExam != null) ...[
          const SizedBox(height: AppSpacing.gap3),
          SoftCard(
            padding: const EdgeInsets.all(AppSpacing.gap3),
            child: Row(
              children: [
                IconChip(
                  icon: Icons.trending_up_rounded,
                  accent: accent.exam,
                  size: 32,
                  iconSize: 16,
                ),
                const SizedBox(width: AppSpacing.gap3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '最近考试：$latestExam',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      if (latestAvg != null)
                        Text(
                          '班级平均分 ${latestAvg.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '${scheduleFill.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: accent.schedule,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '课表',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final Color accent;
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SoftCard(
      padding: const EdgeInsets.all(AppSpacing.gap4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconChip(icon: icon, accent: accent),
          const SizedBox(height: AppSpacing.gap3),
          AnimatedCounter(
            value: value,
            style: TextStyle(
              fontSize: 24,
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
              fontSize: 12,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty onboarding (no class yet) ───────────────────────────────────────

class _EmptyHomeOnboarding extends ConsumerWidget {
  const _EmptyHomeOnboarding();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final palette = ref.watch(themeProvider).palette;
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.pagePadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      gradient: AppGradient.hero(palette, brightness),
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      boxShadow: AppShadow.tinted(palette.seed),
                    ),
                    child: const Icon(Icons.school_rounded,
                        size: 48, color: Colors.white),
                  )
                      .animate()
                      .scale(
                          begin: const Offset(0.8, 0.8),
                          end: const Offset(1, 1),
                          duration: AppMotion.long,
                          curve: AppMotion.spring),
                  const SizedBox(height: AppSpacing.gap5),
                  Text(
                    '欢迎使用教师助手 👋',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.gap2),
                  Text(
                    '先创建一个班级，或用邀请码加入已有班级，开始你的教学旅程',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: scheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.gap5),
                  FilledButton.icon(
                    onPressed: () =>
                        showClassSwitcherSheet(context, ref),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('创建 / 加入班级'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.gap5, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.lg)),
                      textStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.gap3),
                  TextButton.icon(
                    onPressed: () => context.go(AppRoutes.settings),
                    icon: const Icon(Icons.settings_outlined, size: 16),
                    label: const Text('先去配置 AI / 主题'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Quick actions grid removed (replaced by GradeTrendCard + MoodQuoteCard) ─

// ─── Schedule row ───────────────────────────────────────────────────────────

class _ScheduleRow extends StatelessWidget {
  final ScheduleModel schedule;
  final Color accent;
  const _ScheduleRow({required this.schedule, required this.accent});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.gap2),
      child: SoftCard(
        accent: accent,
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.gap4, 12, AppSpacing.gap3, 12),
        child: Row(
          children: [
            IconChip(
              icon: Icons.access_time_rounded,
              accent: accent,
              size: 36,
              iconSize: 16,
            ),
            const SizedBox(width: AppSpacing.gap3),
            SizedBox(
              width: 28,
              child: Text(
                '${schedule.period}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                  height: 1,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    schedule.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: scheme.onSurface,
                      letterSpacing: -0.1,
                    ),
                  ),
                  if (schedule.teacherName?.isNotEmpty == true)
                    Text(
                      '授课：${schedule.teacherName}',
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            if (schedule.classroom?.isNotEmpty == true)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.s),
                ),
                child: Text(
                  schedule.classroom!,
                  style: TextStyle(
                    fontSize: 11,
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
