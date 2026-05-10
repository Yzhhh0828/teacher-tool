import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/design/tokens.dart';
import '../core/router.dart';
import '../providers/class_provider.dart';
import '../providers/theme_provider.dart';
import 'widgets/class_switcher.dart';
import 'widgets/empty_view.dart';
import 'widgets/page_transitions.dart';
import 'widgets/theme_toggle_button.dart';

/// Shell-level current tab index derived from the current route location.
/// Still public so in-shell quick-jump widgets (e.g. home 6-grid) can read
/// the active index, but navigation MUST go through `context.go()`.
final shellIndexProvider = Provider<int>((ref) => 0);

const _kNarrow = 600.0;
const _kWide = 1100.0;

class ShellScaffold extends ConsumerWidget {
  final Widget child;
  const ShellScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Activate the auto-select listener so that as soon as the class list
    // loads, the first class becomes the current selection — no manual
    // tap on the switcher required.
    ref.watch(classAutoSelectProvider);

    final width = MediaQuery.of(context).size.width;
    final location = GoRouterState.of(context).matchedLocation;
    final index = AppRoutes.indexForLocation(location);

    // No forced redirect: pages that require a class render their own
    // empty-state; pages that don't require a class (settings, AI) render
    // normally even before the user has any class.

    if (width < _kNarrow) {
      return _NarrowLayout(index: index, child: child);
    }
    if (width < _kWide) {
      return _MediumLayout(index: index, child: child);
    }
    return _WideLayout(index: index, child: child);
  }
}

// ─── Destinations ───────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool requiresClass;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.requiresClass = true,
  });
}

class ShellDestinations {
  static const items = <_NavItem>[
    _NavItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      label: '工作台',
    ),
    _NavItem(
      icon: Icons.people_alt_outlined,
      activeIcon: Icons.people_alt_rounded,
      label: '学生',
    ),
    _NavItem(
      icon: Icons.assignment_outlined,
      activeIcon: Icons.assignment_rounded,
      label: '成绩',
    ),
    _NavItem(
      icon: Icons.calendar_view_week_outlined,
      activeIcon: Icons.calendar_view_week_rounded,
      label: '课表',
    ),
    _NavItem(
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
      label: '座位',
    ),
    _NavItem(
      icon: Icons.celebration_outlined,
      activeIcon: Icons.celebration_rounded,
      label: '课堂',
    ),
    _NavItem(
      icon: Icons.emoji_events_outlined,
      activeIcon: Icons.emoji_events_rounded,
      label: '行为',
    ),
    _NavItem(
      icon: Icons.smart_toy_outlined,
      activeIcon: Icons.smart_toy_rounded,
      label: 'AI',
      requiresClass: false,
    ),
    _NavItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      label: '设置',
      requiresClass: false,
    ),
  ];

  static const settingsIndex = 8;

  static bool allowsNoClass(int i) =>
      i >= 0 && i < items.length && !items[i].requiresClass;
}

// ─── Body wrapper ───────────────────────────────────────────────────────────

class _Body extends ConsumerWidget {
  final int index;
  final Widget child;
  const _Body({required this.index, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasClass = ref.watch(currentClassProvider) != null;
    final dest = ShellDestinations.items[index];

    if (!hasClass && dest.requiresClass) {
      return const _NoClassOnboarding();
    }
    return FadeThroughSwitcher(
      child: KeyedSubtree(
        key: ValueKey(index),
        child: child,
      ),
    );
  }
}

// ─── Layouts ────────────────────────────────────────────────────────────────

class _NarrowLayout extends ConsumerWidget {
  final int index;
  final Widget child;
  const _NarrowLayout({required this.index, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final palette = ref.watch(themeProvider).palette;
    final accent = AppAccent(palette).color(index);
    // bottom nav: 工作台 / 学生 / 课表 / AI ; rest go in drawer
    const railIndices = [0, 1, 3, 7];
    final bottomIndex = railIndices.indexOf(index);
    return Scaffold(
      drawer: _AppDrawer(currentIndex: index),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _NarrowRibbon(),
            Expanded(child: _Body(index: index, child: child)),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: bottomIndex < 0 ? 0 : bottomIndex,
        onDestinationSelected: (i) =>
            context.go(AppRoutes.pathForIndex(railIndices[i])),
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: accent.withValues(alpha: 0.16),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 64,
        destinations: [
          for (final i in railIndices)
            NavigationDestination(
              icon: Icon(ShellDestinations.items[i].icon),
              selectedIcon: Icon(
                ShellDestinations.items[i].activeIcon,
                color: AppAccent(palette).color(i),
              ),
              label: ShellDestinations.items[i].label,
            ),
        ],
      ),
    );
  }
}

class _MediumLayout extends ConsumerWidget {
  final int index;
  final Widget child;
  const _MediumLayout({required this.index, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Row(
        children: [
          _SideRail(extended: false, currentIndex: index),
          VerticalDivider(
              width: 1, thickness: 1, color: scheme.outlineVariant),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                    maxWidth: AppSpacing.contentMaxWidth),
                child: _Body(index: index, child: child),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WideLayout extends ConsumerWidget {
  final int index;
  final Widget child;
  const _WideLayout({required this.index, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Row(
        children: [
          _SideRail(extended: true, currentIndex: index),
          VerticalDivider(
              width: 1, thickness: 1, color: scheme.outlineVariant),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                    maxWidth: AppSpacing.contentMaxWidth),
                child: _Body(index: index, child: child),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Side rail (medium + wide) ──────────────────────────────────────────────

class _SideRail extends ConsumerWidget {
  final bool extended;
  final int currentIndex;
  const _SideRail({required this.extended, required this.currentIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final palette = ref.watch(themeProvider).palette;
    final accent = AppAccent(palette);
    final hasClass = ref.watch(currentClassProvider) != null;
    final width = extended
        ? AppSpacing.railWidth
        : AppSpacing.railWidthCompact;

    return Container(
      width: width,
      color: scheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            // ── Logo row ──
            Padding(
              padding: EdgeInsets.fromLTRB(
                extended ? AppSpacing.gap4 : 0,
                AppSpacing.gap5,
                extended ? AppSpacing.gap4 : 0,
                AppSpacing.gap3,
              ),
              child: Row(
                mainAxisAlignment: extended
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  _Logo(palette: palette),
                  if (extended) ...[
                    const SizedBox(width: AppSpacing.gap3),
                    Text(
                      '教师助手',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: scheme.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // ── Class switcher ──
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: extended ? AppSpacing.gap4 : AppSpacing.gap2,
                vertical: AppSpacing.gap2,
              ),
              child: ClassSwitcherHeader(compact: !extended),
            ),
            const SizedBox(height: AppSpacing.gap3),
            // ── Menu ──
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(
                  horizontal: extended ? AppSpacing.gap3 : AppSpacing.gap2,
                ),
                itemCount: ShellDestinations.items.length,
                itemBuilder: (ctx, i) {
                  final item = ShellDestinations.items[i];
                  final disabled = item.requiresClass && !hasClass;
                  final selected = currentIndex == i;
                  return _RailTile(
                    icon: selected ? item.activeIcon : item.icon,
                    label: item.label,
                    extended: extended,
                    selected: selected,
                    disabled: disabled,
                    accent: accent.color(i),
                    onTap: disabled
                        ? null
                        : () => context.go(AppRoutes.pathForIndex(i)),
                  );
                },
              ),
            ),
            // ── Trailing: theme toggle ──
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.gap4),
              child: ThemeToggleButton(size: extended ? 40 : 36),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool extended;
  final bool selected;
  final bool disabled;
  final Color accent;
  final VoidCallback? onTap;
  const _RailTile({
    required this.icon,
    required this.label,
    required this.extended,
    required this.selected,
    required this.disabled,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_RailTile> createState() => _RailTileState();
}

class _RailTileState extends State<_RailTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = widget.disabled
        ? scheme.onSurfaceVariant.withValues(alpha: 0.40)
        : widget.selected
            ? widget.accent
            : scheme.onSurfaceVariant;
    final bg = widget.selected
        ? widget.accent.withValues(alpha: 0.12)
        : _hover && !widget.disabled
            ? scheme.surfaceContainerHighest
            : Colors.transparent;

    final indicator = AnimatedContainer(
      duration: AppMotion.short,
      curve: AppMotion.standard,
      width: 3,
      height: widget.selected ? 20 : 0,
      decoration: BoxDecoration(
        color: widget.selected ? widget.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    );

    final tile = AnimatedContainer(
      duration: AppMotion.short,
      curve: AppMotion.standard,
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: EdgeInsets.symmetric(
        horizontal: widget.extended ? AppSpacing.gap3 : 0,
        vertical: widget.extended ? 10 : 10,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.s),
      ),
      child: widget.extended
          ? Row(
              children: [
                indicator,
                const SizedBox(width: AppSpacing.gap2),
                Icon(widget.icon, size: 22, color: fg),
                const SizedBox(width: AppSpacing.gap3),
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: fg,
                      fontWeight:
                          widget.selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                indicator,
                const SizedBox(height: 2),
                Icon(widget.icon, size: 22, color: fg),
                const SizedBox(height: 4),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: fg,
                    fontWeight:
                        widget.selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
    );

    return MouseRegion(
      cursor: widget.disabled
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: widget.disabled ? '请先选择班级' : widget.label,
          child: tile,
        ),
      ),
    );
  }
}

// ─── Narrow ribbon (top of body in narrow layout) ─────────────────────────

class _NarrowRibbon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          bottom: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.gap3, vertical: AppSpacing.gap2),
      child: Row(
        children: [
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu_rounded),
              tooltip: '导航',
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          const Expanded(child: ClassSwitcherHeader(compact: false)),
          const SizedBox(width: AppSpacing.gap2),
          const ThemeToggleButton(size: 36),
        ],
      ),
    );
  }
}

// ─── Drawer (narrow) ────────────────────────────────────────────────────────

class _AppDrawer extends ConsumerWidget {
  final int currentIndex;
  const _AppDrawer({required this.currentIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final palette = ref.watch(themeProvider).palette;
    final accent = AppAccent(palette);
    final hasClass = ref.watch(currentClassProvider) != null;

    return Drawer(
      backgroundColor: scheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.gap4),
              child: Row(
                children: [
                  _Logo(palette: palette),
                  const SizedBox(width: AppSpacing.gap3),
                  Text('教师助手',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      )),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.gap4),
              child: ClassSwitcherHeader(compact: false),
            ),
            const SizedBox(height: AppSpacing.gap3),
            Expanded(
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.gap3),
                itemCount: ShellDestinations.items.length,
                itemBuilder: (ctx, i) {
                  final item = ShellDestinations.items[i];
                  final disabled = item.requiresClass && !hasClass;
                  return _RailTile(
                    icon: currentIndex == i ? item.activeIcon : item.icon,
                    label: item.label,
                    extended: true,
                    selected: currentIndex == i,
                    disabled: disabled,
                    accent: accent.color(i),
                    onTap: disabled
                        ? null
                        : () {
                            context.go(AppRoutes.pathForIndex(i));
                            Navigator.pop(context);
                          },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── No-class onboarding ────────────────────────────────────────────────────

class _NoClassOnboarding extends ConsumerWidget {
  const _NoClassOnboarding();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(themeProvider).palette;
    final accent = AppAccent(palette).classes;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.gap5),
          child: EmptyView(
            icon: Icons.school_rounded,
            title: '欢迎，老师 👋',
            message: '所有功能模块都基于一个班级。\n创建你的第一个班级或加入已有班级，开始今天的教学。',
            accent: accent,
            action: Wrap(
              spacing: AppSpacing.gap3,
              runSpacing: AppSpacing.gap3,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('新建班级'),
                  onPressed: () => showCreateClassDialog(context, ref),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.group_add_rounded, size: 18),
                  label: const Text('加入班级'),
                  onPressed: () => showJoinClassDialog(context, ref),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Logo ───────────────────────────────────────────────────────────────────

class _Logo extends StatelessWidget {
  final AppPalette palette;
  const _Logo({required this.palette});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.seed, palette.tertiary],
        ),
        borderRadius: BorderRadius.circular(AppRadius.s),
      ),
      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
    );
  }
}

// ─── AppAccent helper for nav index ─────────────────────────────────────────

extension on AppAccent {
  Color color(int navIndex) {
    switch (navIndex) {
      case 0:
        return home;
      case 1:
        return student;
      case 2:
        return exam;
      case 3:
        return schedule;
      case 4:
        return seating;
      case 5:
        return presentation;
      case 6:
        return behavior;
      case 7:
        return ai;
      case 8:
      default:
        return neutral;
    }
  }
}
