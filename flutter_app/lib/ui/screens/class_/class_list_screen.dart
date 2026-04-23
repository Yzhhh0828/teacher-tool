import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/class_provider.dart';
import '../../../data/models/class_model.dart';
import '../../../core/theme/app_theme.dart';
import 'class_detail_screen.dart';

class ClassListScreen extends ConsumerWidget {
  const ClassListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(classListProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('我的班级'),
        backgroundColor: AppTheme.backgroundLight,
        surfaceTintColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: () => _showCreateClassDialog(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('创建'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
      body: classesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (classes) => classes.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.school_outlined, size: 56, color: AppTheme.textSecondary.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    Text('还没有班级', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text('点击右上角「创建」新建班级', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () => _showJoinClassDialog(context, ref),
                      icon: const Icon(Icons.group_add_outlined, size: 16),
                      label: const Text('加入已有班级'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: const BorderSide(color: AppTheme.primaryColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceWhite,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: classes.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 60, color: AppTheme.dividerColor),
                      itemBuilder: (context, index) {
                        final class_ = classes[index];
                        final trimmedName = class_.name.trim();
                        final avatarLabel = trimmedName.isEmpty ? '班' : trimmedName.substring(0, 1);
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: CircleAvatar(
                            radius: 21,
                            backgroundColor: AppTheme.primaryColor.withOpacity(0.12),
                            child: Text(
                              avatarLabel,
                              style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                          ),
                          title: Text(class_.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                          subtitle: Text('${class_.grade} 年级', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                          trailing: const Icon(Icons.chevron_right, size: 20, color: AppTheme.textSecondary),
                          onTap: () {
                            ref.read(currentClassProvider.notifier).state = class_;
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ClassDetailScreen(classId: class_.id)),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: () => _showJoinClassDialog(context, ref),
                      icon: const Icon(Icons.group_add_outlined, size: 16),
                      label: const Text('加入已有班级'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: const BorderSide(color: AppTheme.borderLight),
                        backgroundColor: AppTheme.surfaceWhite,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        minimumSize: const Size(180, 0),
                      ),
                    ),
                  ),
                ],
              ),
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
              try {
                await ref.read(classListProvider.notifier).createClass(
                  nameController.text.trim(),
                  gradeController.text.trim(),
                );
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('创建班级失败：$e')),
                  );
                }
              }
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
              try {
                await repository.joinClass(
                  codeController.text.trim(),
                  subjectController.text.trim(),
                );
                await ref.read(classListProvider.notifier).loadClasses();
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('加入班级失败：$e')),
                  );
                }
              }
            },
            child: const Text('加入'),
          ),
        ],
      ),
    );
  }
}
