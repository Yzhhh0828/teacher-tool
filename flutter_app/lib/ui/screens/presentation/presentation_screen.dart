import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/student_provider.dart';
import 'random_call_screen.dart';

class PresentationScreen extends ConsumerWidget {
  const PresentationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentClass = ref.watch(currentClassProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(currentClass?.name ?? '展示端'),
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
              color: Colors.blue,
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
              color: Colors.orange,
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
              color: Colors.green,
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
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Icon(icon, size: 64, color: color),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 48),
            ],
          ),
        ),
      ),
    );
  }
}
