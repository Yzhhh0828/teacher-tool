import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/student_repository.dart';
import '../../data/models/student.dart';
import 'auth_provider.dart';

final studentRepositoryProvider = Provider((ref) => StudentRepository(ref.read(apiClientProvider)));

final studentListProvider = StateNotifierProvider.family<StudentListNotifier, AsyncValue<List<Student>>, int>((ref, classId) {
  return StudentListNotifier(ref.read(studentRepositoryProvider), classId);
});

class StudentListNotifier extends StateNotifier<AsyncValue<List<Student>>> {
  final StudentRepository _repository;
  final int classId;

  StudentListNotifier(this._repository, this.classId) : super(const AsyncValue.loading()) {
    loadStudents();
  }

  Future<void> loadStudents() async {
    state = const AsyncValue.loading();
    try {
      final students = await _repository.getStudents(classId);
      state = AsyncValue.data(students);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addStudent(Student student) async {
    try {
      await _repository.createStudent(classId, student);
      await loadStudents();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateStudent(int studentId, Map<String, dynamic> fields) async {
    try {
      await _repository.updateStudent(studentId, fields);
      await loadStudents();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteStudent(int studentId) async {
    try {
      await _repository.deleteStudent(studentId);
      await loadStudents();
    } catch (e) {
      rethrow;
    }
  }
}
