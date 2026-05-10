import '../../core/config/api_config.dart';
import '../../core/utils/api_client.dart';

class AnalyticsRepository {
  final ApiClient _client;
  AnalyticsRepository(this._client);

  Future<Map<String, dynamic>> classOverview(int classId) async {
    final r = await _client.get(ApiConfig.analyticsClassOverview(classId));
    return Map<String, dynamic>.from(r.data);
  }

  Future<Map<String, dynamic>> examDistribution(int examId, {int bucketSize = 10}) async {
    final r = await _client.get(
      ApiConfig.analyticsExamDistribution(examId),
      queryParameters: {'bucket_size': bucketSize},
    );
    return Map<String, dynamic>.from(r.data);
  }

  Future<Map<String, dynamic>> studentTrend(int studentId, {int limit = 10}) async {
    final r = await _client.get(
      ApiConfig.analyticsStudentTrend(studentId),
      queryParameters: {'limit': limit},
    );
    return Map<String, dynamic>.from(r.data);
  }

  Future<Map<String, dynamic>> classCompare(int classId, {String? subject}) async {
    final r = await _client.get(
      ApiConfig.analyticsClassCompare(classId),
      queryParameters: subject != null ? {'subject': subject} : null,
    );
    return Map<String, dynamic>.from(r.data);
  }
}
