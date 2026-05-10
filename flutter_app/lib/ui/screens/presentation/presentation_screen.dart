import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../widgets/page_transitions.dart';
import '../../widgets/soft_card.dart';
import 'random_call_screen.dart';
import 'random_groups_screen.dart';
import 'random_pick_screen.dart';
import 'timer_screen.dart';

class PresentationScreen extends ConsumerWidget {
  const PresentationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final palette = ref.watch(themeProvider).palette;
    final brightness = Theme.of(context).brightness;
    final accent = AppAccent(palette);
    final heroAccent = accent.presentation;
    final currentClass = ref.watch(currentClassProvider);

    final tools = <_Tool>[
      _Tool(
        icon: Icons.person_search_rounded,
        title: '随机点名',
        subtitle: '老虎机式抽取一名学生',
        accent: palette.seed,
        onTap: () => pushSharedAxis(
            context, (_) => const RandomCallScreen()),
      ),
      _Tool(
        icon: Icons.group_work_rounded,
        title: '随机分组',
        subtitle: '按人数或组数分组',
        accent: palette.secondary,
        onTap: () => pushSharedAxis(
            context, (_) => const RandomGroupsScreen()),
      ),
      _Tool(
        icon: Icons.shuffle_rounded,
        title: '随机抽题',
        subtitle: '从题库抽一道题',
        accent: palette.accent1,
        onTap: () => pushSharedAxis(
            context, (_) => const RandomPickScreen()),
      ),
      _Tool(
        icon: Icons.timer_rounded,
        title: '计时器',
        subtitle: '课堂倒计时',
        accent: palette.accent3,
        onTap: () =>
            pushSharedAxis(context, (_) => const TimerScreen()),
      ),
    ];

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(currentClass?.name ?? '课堂展示'),
        automaticallyImplyLeading: false,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount =
              constraints.maxWidth > 720 ? 4 : 2;
          final aspectRatio =
              constraints.maxWidth > 720 ? 1.0 : 1.25;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.pagePadding,
                AppSpacing.gap4,
                AppSpacing.pagePadding,
                AppSpacing.gap6),
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.gap5),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.gap5,
                    vertical: AppSpacing.gap4),
                decoration: BoxDecoration(
                  gradient: AppGradient.accent(heroAccent, brightness),
                  borderRadius: BorderRadius.circular(AppRadius.l),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.gap3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius:
                            BorderRadius.circular(AppRadius.m),
                      ),
                      child: const Icon(Icons.celebration_rounded,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: AppSpacing.gap4),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('课堂互动工具',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              )),
                          SizedBox(height: 4),
                          Text('点名抽题分组计时，让课堂更有活力',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: AppMotion.short)
                  .moveY(
                      begin: -6,
                      end: 0,
                      duration: AppMotion.short),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: AppSpacing.gap4,
                  crossAxisSpacing: AppSpacing.gap4,
                  childAspectRatio: aspectRatio,
                ),
                itemCount: tools.length,
                itemBuilder: (ctx, i) {
                  final t = tools[i];
                  return _ToolCard(tool: t)
                      .animate(delay: AppMotion.stagger * i)
                      .fadeIn(duration: AppMotion.short)
                      .moveY(
                        begin: 8,
                        end: 0,
                        duration: AppMotion.short,
                        curve: AppMotion.standard,
                      );
                },
              ),
              const SizedBox(height: AppSpacing.gap5),
              Container(
                padding: const EdgeInsets.all(AppSpacing.gap3),
                decoration: AppSurface.tinted(
                    context, heroAccent,
                    radius: AppRadius.m, alpha: 0.08),
                child: Row(
                  children: [
                    Icon(Icons.tips_and_updates_rounded,
                        color: heroAccent, size: 18),
                    const SizedBox(width: AppSpacing.gap2),
                    Expanded(
                      child: Text(
                        '小贴士：随机工具会从当前班级花名册中抽取，请先在「学生管理」中添加学生',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Tool {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;
  const _Tool({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });
}

class _ToolCard extends StatelessWidget {
  final _Tool tool;
  const _ToolCard({required this.tool});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SoftCard(
      onTap: tool.onTap,
      accent: tool.accent,
      padding: const EdgeInsets.all(AppSpacing.gap4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: tool.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.m),
            ),
            child: Icon(tool.icon, color: tool.accent, size: 26),
          ),
          const SizedBox(height: AppSpacing.gap3),
          Text(
            tool.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            tool.subtitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
              fontSize: 11.5,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
