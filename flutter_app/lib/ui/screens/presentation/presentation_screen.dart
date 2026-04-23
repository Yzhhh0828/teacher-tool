import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'random_call_screen.dart';

class PresentationScreen extends ConsumerWidget {
  const PresentationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentClass = ref.watch(currentClassProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text(currentClass?.name ?? '课堂展示'),
        backgroundColor: AppTheme.backgroundLight,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Column(
              children: [
                _ToolTile(
                  icon: Icons.person_search_outlined,
                  title: '随机点名',
                  subtitle: '随机选择一名学生',
                  color: AppTheme.primaryColor,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RandomCallScreen())),
                ),
                const Divider(height: 1, indent: 60, color: AppTheme.dividerColor),
                _ToolTile(
                  icon: Icons.timer_outlined,
                  title: '计时器',
                  subtitle: '课堂倒计时工具（敬请期待）',
                  color: AppTheme.accent,
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('敬请期待...'))),
                ),
                const Divider(height: 1, indent: 60, color: AppTheme.dividerColor),
                _ToolTile(
                  icon: Icons.grid_view_outlined,
                  title: '座位总览',
                  subtitle: '课堂展示班级座位（敬请期待）',
                  color: AppTheme.successColor,
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('敬请期待...'))),
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool isLast;

  const _ToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      trailing: const Icon(Icons.chevron_right, size: 18, color: AppTheme.textSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: onTap,
    );
  }
}
