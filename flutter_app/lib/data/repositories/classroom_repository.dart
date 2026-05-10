import '../../core/config/api_config.dart';
import '../../core/utils/api_client.dart';

class ClassroomRepository {
  final ApiClient _client;
  ClassroomRepository(this._client);

  Future<Map<String, dynamic>> pickRandomStudent(
    int classId, {
    int avoidRecentMinutes = 60,
    List<int> excludeIds = const [],
  }) async {
    final r = await _client.post(
      ApiConfig.classroomPick(classId),
      data: {
        'avoid_recent_minutes': avoidRecentMinutes,
        'exclude_ids': excludeIds,
      },
    );
    return Map<String, dynamic>.from(r.data);
  }

  Future<List<List<Map<String, dynamic>>>> randomGroups(
    int classId, {
    int? groupSize,
    int? groupCount,
    int? seed,
  }) async {
    final r = await _client.post(
      ApiConfig.classroomGroups(classId),
      data: {
        if (groupSize != null) 'group_size': groupSize,
        if (groupCount != null) 'group_count': groupCount,
        if (seed != null) 'seed': seed,
      },
    );
    final groups = (r.data['groups'] as List)
        .map<List<Map<String, dynamic>>>(
          (g) => (g as List).map<Map<String, dynamic>>((m) => Map<String, dynamic>.from(m)).toList(),
        )
        .toList();
    return groups;
  }

  Future<List<Map<String, dynamic>>> listEvents(int classId, {String? eventType, int limit = 50}) async {
    final r = await _client.get(
      ApiConfig.classroomEvents(classId),
      queryParameters: {
        if (eventType != null) 'event_type': eventType,
        'limit': limit,
      },
    );
    return List<Map<String, dynamic>>.from(r.data['items']);
  }
}
