import '../../core/config/api_config.dart';
import '../../core/utils/api_client.dart';
import '../models/behavior.dart';

class BehaviorRepository {
  final ApiClient _client;

  BehaviorRepository(this._client);

  // ─── Categories ─────────────────────────────────────────────────────────────

  Future<List<BehaviorCategory>> getCategories(int classId) async {
    final resp = await _client.get(ApiConfig.behaviorCategories(classId));
    return (resp.data as List)
        .map((j) => BehaviorCategory.fromJson(j))
        .toList();
  }

  Future<BehaviorCategory> createCategory(
    int classId, {
    required String name,
    required String icon,
    required double score,
    int sortOrder = 0,
  }) async {
    final resp = await _client.post(
      ApiConfig.behaviorCategories(classId),
      data: {'name': name, 'icon': icon, 'score': score, 'sort_order': sortOrder},
    );
    return BehaviorCategory.fromJson(resp.data);
  }

  Future<void> deleteCategory(int categoryId) async {
    await _client.delete('/behavior/categories/$categoryId');
  }

  // ─── Records ────────────────────────────────────────────────────────────────

  Future<List<BehaviorRecord>> createRecords(
    int classId, {
    required List<int> studentIds,
    required int categoryId,
    String? note,
  }) async {
    final resp = await _client.post(
      ApiConfig.behaviorRecords(classId),
      data: {
        'student_ids': studentIds,
        'category_id': categoryId,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return (resp.data as List)
        .map((j) => BehaviorRecord.fromJson(j))
        .toList();
  }

  Future<List<BehaviorRecord>> getClassRecords(
    int classId, {
    int? studentId,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      if (studentId != null) 'student_id': studentId,
    };
    final resp = await _client.get(
      ApiConfig.behaviorRecords(classId),
      queryParameters: params,
    );
    return (resp.data as List)
        .map((j) => BehaviorRecord.fromJson(j))
        .toList();
  }

  Future<void> deleteRecord(int recordId) async {
    await _client.delete('/behavior/records/$recordId');
  }

  // ─── Stats ──────────────────────────────────────────────────────────────────

  Future<List<StudentScore>> getLeaderboard(int classId) async {
    final resp = await _client.get(ApiConfig.behaviorStats(classId));
    return (resp.data as List)
        .map((j) => StudentScore.fromJson(j))
        .toList();
  }
}
