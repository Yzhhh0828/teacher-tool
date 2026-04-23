import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import 'screens/home/home_screen.dart';
import 'screens/class_/class_list_screen.dart';
import 'screens/settings/settings_screen.dart';
import '../agent/chat_screen.dart';

final _shellIndexProvider = StateProvider<int>((ref) => 0);

// Breakpoints
const _kNarrow = 600.0;   // < 600  → bottom bar
const _kWide   = 1100.0;  // ≥ 1100 → expanded rail with labels

// Max content width for the body area
const _kContentMaxWidth = 720.0;

class ShellScaffold extends ConsumerWidget {
  const ShellScaffold({super.key});

  static const _destinations = [
    _NavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: '工作台'),
    _NavItem(icon: Icons.school_outlined,    activeIcon: Icons.school_rounded,    label: '班级'),
    _NavItem(icon: Icons.smart_toy_outlined, activeIcon: Icons.smart_toy_rounded, label: 'AI 助手'),
    _NavItem(icon: Icons.settings_outlined,  activeIcon: Icons.settings_rounded,  label: '设置'),
  ];

  static const _pages = [
    HomeScreen(),
    ClassListScreen(),
    ChatScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final index  = ref.watch(_shellIndexProvider);

    if (width < _kNarrow) return _NarrowLayout(index: index, ref: ref);
    if (width < _kWide)   return _MediumLayout(index: index, ref: ref);
    return _WideLayout(index: index, ref: ref);
  }
}

// ─── Narrow (<600): bottom NavigationBar ─────────────────────────────────────
class _NarrowLayout extends StatelessWidget {
  final int index; final WidgetRef ref;
  const _NarrowLayout({required this.index, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: ShellScaffold._pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => ref.read(_shellIndexProvider.notifier).state = i,
        backgroundColor: AppTheme.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black12,
        elevation: 4,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: AppTheme.primaryColor.withOpacity(0.12),
        destinations: ShellScaffold._destinations
            .map((d) => NavigationDestination(
                  icon: Icon(d.icon, color: AppTheme.textSecondary),
                  selectedIcon: Icon(d.activeIcon, color: AppTheme.primaryColor),
                  label: d.label,
                ))
            .toList(),
      ),
    );
  }
}

// ─── Medium (600–1099): compact icon rail + constrained content ───────────────
class _MediumLayout extends StatelessWidget {
  final int index; final WidgetRef ref;
  const _MediumLayout({required this.index, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: Row(
        children: [
          _Rail(index: index, ref: ref, extended: false),
          const VerticalDivider(width: 1, thickness: 1, color: AppTheme.dividerColor),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kContentMaxWidth),
                child: ShellScaffold._pages[index],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Wide (≥1100): expanded rail with labels + constrained content ────────────
class _WideLayout extends StatelessWidget {
  final int index; final WidgetRef ref;
  const _WideLayout({required this.index, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: Row(
        children: [
          _Rail(index: index, ref: ref, extended: true),
          const VerticalDivider(width: 1, thickness: 1, color: AppTheme.dividerColor),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kContentMaxWidth),
                child: ShellScaffold._pages[index],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared NavigationRail ────────────────────────────────────────────────────
class _Rail extends StatelessWidget {
  final int index;
  final WidgetRef ref;
  final bool extended;
  const _Rail({required this.index, required this.ref, required this.extended});

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      backgroundColor: AppTheme.surfaceWhite,
      selectedIndex: index,
      onDestinationSelected: (i) => ref.read(_shellIndexProvider.notifier).state = i,
      extended: extended,
      minWidth: extended ? 200 : 84,
      labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
      selectedIconTheme: const IconThemeData(color: AppTheme.primaryColor, size: 26),
      unselectedIconTheme: IconThemeData(color: AppTheme.textSecondary.withOpacity(0.65), size: 26),
      selectedLabelTextStyle: const TextStyle(
        color: AppTheme.primaryColor,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: AppTheme.textSecondary.withOpacity(0.8),
        fontSize: 13,
      ),
      indicatorColor: AppTheme.primaryColor.withOpacity(0.10),
      leading: Padding(
        padding: EdgeInsets.only(top: 24, bottom: extended ? 20 : 12),
        child: extended
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '教师助手',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              )
            : Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
              ),
      ),
      destinations: ShellScaffold._destinations
          .map((d) => NavigationRailDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.activeIcon),
                label: Text(d.label),
                padding: const EdgeInsets.symmetric(vertical: 2),
              ))
          .toList(),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
}
