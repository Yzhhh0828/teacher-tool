import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/grade_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/class_provider.dart';
import '../../../data/models/grade.dart';
import '../../../data/models/student.dart';

class GradeEntryScreen extends ConsumerStatefulWidget {
  final Exam exam;

  const GradeEntryScreen({
    super.key,
    required this.exam,
  });

  @override
  ConsumerState<GradeEntryScreen> createState() => _GradeEntryScreenState();
}

class _GradeEntryScreenState extends ConsumerState<GradeEntryScreen> {
  final Map<int, TextEditingController> _scoreControllers = {};
  final Map<int, TextEditingController> _remarksControllers = {};
  String _selectedSubject = '语文';

  static const List<String> _subjects = ['语文', '数学', '英语', '物理', '化学', '生物', '历史', '地理', '政治'];

  @override
  void dispose() {
    for (final controller in _scoreControllers.values) {
      controller.dispose();
    }
    for (final controller in _remarksControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentClass = ref.watch(currentClassProvider);
    if (currentClass == null) {
      return const Center(child: Text('请先选择班级'));
    }

    final studentsAsync = ref.watch(studentListProvider(currentClass.id));
    final gradesAsync = ref.watch(examGradesProvider(widget.exam.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.exam.name} - 成绩录入'),
      ),
      body: Column(
        children: [
          // Subject selector
          Container(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              value: _selectedSubject,
              decoration: const InputDecoration(
                labelText: '科目',
                border: OutlineInputBorder(),
              ),
              items: _subjects.map((subject) {
                return DropdownMenuItem(value: subject, child: Text(subject));
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedSubject = value);
                }
              },
            ),
          ),
          // Student list with grade entry
          Expanded(
            child: studentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (students) {
                if (students.isEmpty) {
                  return const Center(child: Text('暂无学生'));
                }
                return gradesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (grades) => _buildStudentGradeList(students, grades),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentGradeList(List<Student> students, List<Grade> grades) {
    // Create a map of student_id -> grade for quick lookup
    final gradeMap = {for (var g in grades) g.studentId: g};

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        final existingGrade = gradeMap[student.id];

        // Initialize controllers
        _scoreControllers.putIfAbsent(
          student.id,
          () => TextEditingController(
            text: existingGrade?.score.toString() ?? '',
          ),
        );
        _remarksControllers.putIfAbsent(
          student.id,
          () => TextEditingController(
            text: existingGrade?.remarks ?? '',
          ),
        );

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      child: Text(student.name[0]),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _formatGender(student.gender),
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _scoreControllers[student.id],
                        decoration: const InputDecoration(
                          labelText: '分数',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _remarksControllers[student.id],
                        decoration: const InputDecoration(
                          labelText: '备注',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => _saveGrade(student.id),
                    child: const Text('保存'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatGender(String? gender) {
    switch (gender) {
      case 'male':
        return '男';
      case 'female':
        return '女';
      default:
        return gender ?? '';
    }
  }

  Future<void> _saveGrade(int studentId) async {
    final scoreText = _scoreControllers[studentId]?.text.trim() ?? '';
    final remarks = _remarksControllers[studentId]?.text.trim();

    if (scoreText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入分数')),
      );
      return;
    }

    final score = double.tryParse(scoreText);
    if (score == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的分数')),
      );
      return;
    }

    final grade = Grade(
      id: 0,
      examId: widget.exam.id,
      studentId: studentId,
      subject: _selectedSubject,
      score: score,
      remarks: remarks?.isEmpty == true ? null : remarks,
      createdAt: DateTime.now(),
    );

    try {
      await ref.read(examGradesProvider(widget.exam.id).notifier).saveGrade(grade);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
