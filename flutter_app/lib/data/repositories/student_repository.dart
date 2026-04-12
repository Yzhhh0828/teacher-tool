import '../../core/config/api_config.dart';
import '../../core/utils/api_client.dart';
import '../models/student.dart';

class StudentRepository {
  final ApiClient _client;

  StudentRepository(this._client);

  Future<List<Student>> getStudents(int classId) async {
    final response = await _client.get(ApiConfig.classStudents(classId));
    return (response.data as List)
        .map((json) => Student.fromJson(json))
        .toList();
  }

  Future<Student> createStudent(int classId, Student student) async {
    final data = student.toJson();
    data['class_id'] = classId;
    final response = await _client.post(ApiConfig.students, data: data);
    return Student.fromJson(response.data);
  }

  Future<Student> updateStudent(int studentId, Map<String, dynamic> fields) async {
    final response = await _client.put(
      '${ApiConfig.students}/$studentId',
      data: fields,
    );
    return Student.fromJson(response.data);
  }

  Future<void> deleteStudent(int studentId) async {
    await _client.delete(ApiConfig.student(studentId));
  }
}
