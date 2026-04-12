import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/class_provider.dart';
import '../../../data/models/class_model.dart';
import 'class_detail_screen.dart';

class ClassListScreen extends ConsumerWidget {
  const ClassListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(classListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的班级'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateClassDialog(context, ref),
          ),
        ],
      ),
      body: classesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (classes) => classes.isEmpty
            ? const Center(child: Text('暂无班级，点击+创建'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: classes.length,
                itemBuilder: (context, index) {
                  final class_ = classes[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(class_.name[0]),
                      ),
                      title: Text(class_.name),
                      subtitle: Text('${class_.grade}年级'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        ref.read(currentClassProvider.notifier).state = class_;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClassDetailScreen(classId: class_.id),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showJoinClassDialog(context, ref),
        child: const Icon(Icons.group_add),
      ),
    );
  }

  void _showCreateClassDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final gradeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建班级'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '班级名称'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: gradeController,
              decoration: const InputDecoration(labelText: '年级'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(classListProvider.notifier).createClass(
                nameController.text,
                gradeController.text,
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _showJoinClassDialog(BuildContext context, WidgetRef ref) {
    final codeController = TextEditingController();
    final subjectController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('加入班级'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              decoration: const InputDecoration(labelText: '邀请码'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: subjectController,
              decoration: const InputDecoration(labelText: '教授科目'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final repository = ref.read(classRepositoryProvider);
              await repository.joinClass(
                codeController.text,
                subjectController.text,
              );
              await ref.read(classListProvider.notifier).loadClasses();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('加入'),
          ),
        ],
      ),
    );
  }
}
