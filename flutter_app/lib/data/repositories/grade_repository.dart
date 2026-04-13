import '../../core/config/api_config.dart';
import '../../core/utils/api_client.dart';
import '../models/grade.dart';

class GradeRepository {
  final ApiClient _client;

  GradeRepository(this._client);

  // Exams
  Future<List<Exam>> getExams(int classId) async {
    final response = await _client.get(ApiConfig.classExams(classId));
    return (response.data as List).map((json) => Exam.fromJson(json)).toList();
  }

  Future<Exam> createExam(int classId, Exam exam) async {
    final data = exam.toJson();
    data['class_id'] = classId;
    final response = await _client.post(ApiConfig.exams, data: data);
    return Exam.fromJson(response.data);
  }

  Future<void> deleteExam(int examId) async {
    await _client.delete('${ApiConfig.exams}/$examId');
  }

  // Grades
  Future<List<Grade>> getExamGrades(int examId) async {
    final response = await _client.get(ApiConfig.examGrades(examId));
    return (response.data as List).map((json) => Grade.fromJson(json)).toList();
  }

  Future<Grade> createGrade(int examId, Grade grade) async {
    final data = grade.toJson();
    data['exam_id'] = examId;
    final response = await _client.post(
      ApiConfig.grades,
      data: data,
    );
    return Grade.fromJson(response.data);
  }
}
