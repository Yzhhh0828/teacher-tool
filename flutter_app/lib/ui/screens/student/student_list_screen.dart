import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/class_provider.dart';
import 'student_form_screen.dart';

class StudentListScreen extends ConsumerWidget {
  const StudentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentClass = ref.watch(currentClassProvider);
    if (currentClass == null) {
      return const Center(child: Text('请先选择班级'));
    }

    final studentsAsync = ref.watch(studentListProvider(currentClass.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('学生管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentFormScreen(classId: currentClass.id),
                ),
              );
            },
          ),
        ],
      ),
      body: studentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (students) => students.isEmpty
            ? const Center(child: Text('暂无学生，点击+添加'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: students.length,
                itemBuilder: (context, index) {
                  final student = students[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(student.name[0]),
                      ),
                      title: Text(student.name),
                      subtitle: Text('${student.gender} | ${student.phone ?? "无电话"}'),
                      trailing: PopupMenuButton(
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: Text('编辑')),
                          const PopupMenuItem(value: 'delete', child: Text('删除')),
                        ],
                        onSelected: (value) async {
                          if (value == 'edit') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StudentFormScreen(
                                  classId: currentClass.id,
                                  student: student,
                                ),
                              ),
                            );
                          } else if (value == 'delete') {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('确认删除'),
                                content: Text('确定要删除学生 ${student.name} 吗？'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('取消'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('删除'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await ref
                                  .read(studentListProvider(currentClass.id).notifier)
                                  .deleteStudent(student.id);
                            }
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
