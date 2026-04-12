import '../../core/config/api_config.dart';
import '../../core/utils/api_client.dart';
import '../models/seating.dart';

class SeatingRepository {
  final ApiClient _client;

  SeatingRepository(this._client);

  Future<SeatingModel?> getSeating(int classId) async {
    try {
      final response = await _client.get(ApiConfig.seating(classId));
      return SeatingModel.fromJson(response.data);
    } catch (e) {
      return null; // No seating exists yet
    }
  }

  Future<SeatingModel> createOrUpdateSeating(int classId, int rows, int cols) async {
    final response = await _client.post(
      ApiConfig.seating(classId),
      data: {'rows': rows, 'cols': cols},
    );
    return SeatingModel.fromJson(response.data);
  }

  Future<SeatingModel> shuffleSeats(int classId) async {
    final response = await _client.post(ApiConfig.shuffleSeats(classId));
    return SeatingModel.fromJson(response.data);
  }

  Future<void> updateSeat(int classId, int row, int col, int? studentId) async {
    await _client.put(
      ApiConfig.seating(classId),
      data: {'row': row, 'col': col, 'student_id': studentId},
    );
  }
}
