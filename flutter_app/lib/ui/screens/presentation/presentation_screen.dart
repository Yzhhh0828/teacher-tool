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
      appBar: AppBar(
        title: Text(currentClass?.name ?? '课堂展示'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PresentationCard(
              icon: Icons.person_search,
              title: '随机点名',
              subtitle: '随机选择一个学生',
              color: AppTheme.primaryColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RandomCallScreen()),
                );
              },
            ),
            const SizedBox(height: 16),
            _PresentationCard(
              icon: Icons.timer,
              title: '计时器',
              subtitle: '课堂计时工具',
              color: AppTheme.accent,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('敬请期待...')),
                );
              },
            ),
            const SizedBox(height: 16),
            _PresentationCard(
              icon: Icons.grid_view,
              title: '座位表',
              subtitle: '查看班级座位',
              color: AppTheme.successColor,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('敬请期待...')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PresentationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _PresentationCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 24, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
