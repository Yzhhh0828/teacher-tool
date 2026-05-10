import '../../core/config/api_config.dart';
import '../../core/utils/api_client.dart';
import '../models/seating.dart';

class SeatingRepository {
  final ApiClient _client;

  SeatingRepository(this._client);

  // ── Active seating ──

  Future<SeatingModel> getSeating(int classId) async {
    final response = await _client.get(ApiConfig.seating(classId));
    return SeatingModel.fromJson(response.data);
  }

  Future<SeatingModel> createOrUpdateSeating(int classId, int rows, int cols) async {
    final response = await _client.put(
      ApiConfig.seating(classId),
      data: {'rows': rows, 'cols': cols},
    );
    return SeatingModel.fromJson(response.data);
  }

  Future<SeatingModel> saveSeating(int classId, int rows, int cols, List<List<int?>> seats) async {
    final response = await _client.put(
      ApiConfig.seating(classId),
      data: {'rows': rows, 'cols': cols, 'seats': seats},
    );
    return SeatingModel.fromJson(response.data);
  }

  Future<SeatingModel> shuffleSeats(int classId) async {
    await _client.post(ApiConfig.shuffleSeats(classId));
    final seating = await getSeating(classId);
    return seating;
  }

  Future<void> updateSeat(int classId, int row, int col, int? studentId) async {
    final seating = await getSeating(classId);
    final seats = seating.seats
        .map((seatRow) => List<int?>.from(seatRow))
        .toList();

    if (row < 0 || row >= seats.length || col < 0 || col >= seats[row].length) {
      throw Exception('座位坐标超出范围');
    }

    seats[row][col] = studentId;

    await _client.put(
      ApiConfig.seating(classId),
      data: {
        'rows': seating.rows,
        'cols': seating.cols,
        'seats': seats,
      },
    );
  }

  // ── Saved layouts ──

  Future<List<Map<String, dynamic>>> listLayouts(int classId) async {
    final response = await _client.get(ApiConfig.seatingLayouts(classId));
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createLayout(int classId, Map<String, dynamic> data) async {
    final response = await _client.post(ApiConfig.seatingLayouts(classId), data: data);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> deleteLayout(int layoutId) async {
    await _client.delete(ApiConfig.seatingLayout(layoutId));
  }

  Future<SeatingModel> applyLayout(int layoutId) async {
    final response = await _client.post(ApiConfig.applyLayout(layoutId));
    return SeatingModel.fromJson(response.data);
  }
}
