import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/class_provider.dart';
import '../../../data/models/student.dart';
import '../../../core/theme/app_theme.dart';

class StudentListScreen extends ConsumerStatefulWidget {
  const StudentListScreen({super.key});

  @override
  ConsumerState<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends ConsumerState<StudentListScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final currentClass = ref.watch(currentClassProvider);
    if (currentClass == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('学生管理')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_outline, size: 48, color: AppTheme.textSecondary.withOpacity(0.3)),
              const SizedBox(height: 12),
              const Text('请先在「班级」中选择班级'),
            ],
          ),
        ),
      );
    }

    final studentsAsync = ref.watch(studentListProvider(currentClass.id));

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text(currentClass.name),
        backgroundColor: AppTheme.backgroundLight,
        surfaceTintColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: () => _showAddStudentDialog(context, currentClass.id),
              icon: const Icon(Icons.person_add_outlined, size: 16),
              label: const Text('添加'),
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
      body: studentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (students) {
          final filtered = _search.isEmpty
              ? students
              : students.where((s) => s.name.contains(_search)).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: '搜索学生姓名…',
                    prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textSecondary),
                    isDense: true,
                    filled: true,
                    fillColor: AppTheme.surfaceWhite,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.borderLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.borderLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.primaryColor),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (students.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline, size: 56, color: AppTheme.textSecondary.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text('暂无学生', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Text('点击右上角「添加」添加学生', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                )
              else if (filtered.isEmpty)
                Expanded(
                  child: Center(
                    child: Text('未找到「$_search」', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary)),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 56, color: AppTheme.dividerColor),
                    itemBuilder: (context, index) {
                      final student = filtered[index];
                      final isMale = student.gender == 'male';
                      return Dismissible(
                        key: ValueKey(student.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: AppTheme.errorColor.withOpacity(0.1),
                          child: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
                        ),
                        confirmDismiss: (_) => _confirmDelete(context, student.name),
                        onDismissed: (_) async {
                          await ref.read(studentListProvider(currentClass.id).notifier).deleteStudent(student.id);
                        },
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 21,
                            backgroundColor: isMale
                                ? AppTheme.primaryColor.withOpacity(0.12)
                                : AppTheme.accent.withOpacity(0.15),
                            child: Text(
                              student.name.isNotEmpty ? student.name.substring(0, 1) : '?',
                              style: TextStyle(
                                color: isMale ? AppTheme.primaryColor : AppTheme.primaryDark,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                          subtitle: Text(isMale ? '男' : '女', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.textSecondary),
                            onPressed: () => _showEditStudentDialog(context, currentClass.id, student),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, String name) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('删除学生'),
            content: Text('确定要删除「$name」吗？'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showAddStudentDialog(BuildContext context, int classId) {
    final nameCtrl = TextEditingController();
    String gender = 'male';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('添加学生'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '姓名 *', isDense: true)),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('性别：'),
                  const SizedBox(width: 8),
                  ChoiceChip(label: const Text('男'), selected: gender == 'male', onSelected: (_) => setState(() => gender = 'male')),
                  const SizedBox(width: 8),
                  ChoiceChip(label: const Text('女'), selected: gender == 'female', onSelected: (_) => setState(() => gender = 'female')),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final student = Student(id: 0, classId: classId, name: nameCtrl.text.trim(), gender: gender, phone: null, parentPhone: null, remarks: null, createdAt: DateTime.now());
                try {
                  await ref.read(studentListProvider(classId).notifier).addStudent(student);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('添加失败：$e')));
                }
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditStudentDialog(BuildContext context, int classId, Student student) {
    final nameCtrl = TextEditingController(text: student.name);
    String gender = student.gender;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('编辑学生'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '姓名 *', isDense: true)),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('性别：'),
                  const SizedBox(width: 8),
                  ChoiceChip(label: const Text('男'), selected: gender == 'male', onSelected: (_) => setState(() => gender = 'male')),
                  const SizedBox(width: 8),
                  ChoiceChip(label: const Text('女'), selected: gender == 'female', onSelected: (_) => setState(() => gender = 'female')),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                try {
                  await ref.read(studentListProvider(classId).notifier).updateStudent(
                        student.id,
                        {'name': nameCtrl.text.trim(), 'gender': gender},
                      );
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新失败：$e')));
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
