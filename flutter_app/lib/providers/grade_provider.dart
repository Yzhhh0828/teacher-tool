import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/grade_repository.dart';
import '../../data/models/grade.dart';
import 'auth_provider.dart';

final gradeRepositoryProvider = Provider((ref) => GradeRepository(ref.read(apiClientProvider)));

final examListProvider = StateNotifierProvider.family<ExamListNotifier, AsyncValue<List<Exam>>, int>((ref, classId) {
  return ExamListNotifier(ref.read(gradeRepositoryProvider), classId);
});

class ExamListNotifier extends StateNotifier<AsyncValue<List<Exam>>> {
  final GradeRepository _repository;
  final int classId;

  ExamListNotifier(this._repository, this.classId) : super(const AsyncValue.loading()) {
    loadExams();
  }

  Future<void> loadExams() async {
    state = const AsyncValue.loading();
    try {
      final exams = await _repository.getExams(classId);
      state = AsyncValue.data(exams);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addExam(Exam exam) async {
    try {
      await _repository.createExam(classId, exam);
      await loadExams();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteExam(int examId) async {
    try {
      await _repository.deleteExam(examId);
      await loadExams();
    } catch (e) {
      rethrow;
    }
  }
}

final examGradesProvider = StateNotifierProvider.family<ExamGradesNotifier, AsyncValue<List<Grade>>, int>((ref, examId) {
  return ExamGradesNotifier(ref.read(gradeRepositoryProvider), examId);
});

class ExamGradesNotifier extends StateNotifier<AsyncValue<List<Grade>>> {
  final GradeRepository _repository;
  final int examId;

  ExamGradesNotifier(this._repository, this.examId) : super(const AsyncValue.loading()) {
    loadGrades();
  }

  Future<void> loadGrades() async {
    state = const AsyncValue.loading();
    try {
      final grades = await _repository.getExamGrades(examId);
      state = AsyncValue.data(grades);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> saveGrade(Grade grade) async {
    try {
      await _repository.createOrUpdateGrade(examId, grade);
      await loadGrades();
    } catch (e) {
      rethrow;
    }
  }
}
