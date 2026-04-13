import '../../core/config/api_config.dart';
import '../../core/utils/api_client.dart';
import '../models/schedule.dart';

class ScheduleRepository {
  final ApiClient _client;

  ScheduleRepository(this._client);

  Future<List<ScheduleModel>> getSchedules(int classId) async {
    final response = await _client.get(ApiConfig.classSchedules(classId));
    return (response.data as List)
        .map((json) => ScheduleModel.fromJson(json))
        .toList();
  }

  Future<ScheduleModel> createSchedule(ScheduleModel schedule) async {
    final response = await _client.post(
      ApiConfig.schedules,
      data: schedule.toJson(),
    );
    return ScheduleModel.fromJson(response.data);
  }

  Future<void> deleteSchedule(int scheduleId) async {
    await _client.delete(ApiConfig.schedule(scheduleId));
  }
}
