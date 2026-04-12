import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/class_provider.dart';

class RandomCallScreen extends ConsumerStatefulWidget {
  const RandomCallScreen({super.key});

  @override
  ConsumerState<RandomCallScreen> createState() => _RandomCallScreenState();
}

class _RandomCallScreenState extends ConsumerState<RandomCallScreen> {
  String? _selectedStudent;
  final _random = Random();

  void _pickRandomStudent() {
    final currentClass = ref.read(currentClassProvider);
    if (currentClass == null) return;

    final studentsAsync = ref.read(studentListProvider(currentClass.id));
    studentsAsync.whenData((students) {
      if (students.isEmpty) {
        setState(() => _selectedStudent = '暂无学生');
        return;
      }

      final student = students[_random.nextInt(students.length)];
      setState(() => _selectedStudent = student.name);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('随机点名'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _selectedStudent ?? '点击按钮开始',
                key: ValueKey(_selectedStudent),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: _pickRandomStudent,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                textStyle: const TextStyle(fontSize: 24),
              ),
              child: const Text('随机选择'),
            ),
          ],
        ),
      ),
    );
  }
}
