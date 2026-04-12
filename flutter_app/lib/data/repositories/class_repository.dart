import '../../core/config/api_config.dart';
import '../../core/utils/api_client.dart';
import '../models/class_model.dart';

class ClassRepository {
  final ApiClient _client;

  ClassRepository(this._client);

  Future<List<ClassModel>> getClasses() async {
    final response = await _client.get(ApiConfig.classes);
    return (response.data as List)
        .map((json) => ClassModel.fromJson(json))
        .toList();
  }

  Future<ClassModel> createClass(String name, String grade) async {
    final response = await _client.post(
      ApiConfig.classes,
      data: {'name': name, 'grade': grade},
    );
    return ClassModel.fromJson(response.data);
  }

  Future<ClassModel> getClassDetail(int classId) async {
    final response = await _client.get(ApiConfig.classDetail(classId));
    return ClassModel.fromJson(response.data);
  }

  Future<String> createInviteCode(int classId) async {
    final response = await _client.post(ApiConfig.createInviteCode(classId));
    return response.data['invite_code'];
  }

  Future<void> joinClass(String inviteCode, String subject) async {
    await _client.post(
      ApiConfig.joinClass,
      data: {'invite_code': inviteCode, 'subject': subject},
    );
  }

  Future<void> deleteClass(int classId) async {
    await _client.delete(ApiConfig.classDetail(classId));
  }
}
