import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/seating_repository.dart';
import '../../data/models/seating.dart';
import 'auth_provider.dart';

final seatingRepositoryProvider = Provider((ref) => SeatingRepository(ref.read(apiClientProvider)));

final seatingProvider = StateNotifierProvider.family<SeatingNotifier, AsyncValue<SeatingModel>, int>((ref, classId) {
  return SeatingNotifier(ref.read(seatingRepositoryProvider), classId);
});

class SeatingNotifier extends StateNotifier<AsyncValue<SeatingModel>> {
  final SeatingRepository _repository;
  final int classId;

  SeatingNotifier(this._repository, this.classId) : super(const AsyncValue.loading()) {
    loadSeating();
  }

  Future<void> loadSeating() async {
    state = const AsyncValue.loading();
    try {
      final seating = await _repository.getSeating(classId);
      state = AsyncValue.data(seating);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createSeating(int rows, int cols) async {
    try {
      final seating = await _repository.createOrUpdateSeating(classId, rows, cols);
      state = AsyncValue.data(seating);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> shuffleSeats() async {
    try {
      final seating = await _repository.shuffleSeats(classId);
      state = AsyncValue.data(seating);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateSeat(int row, int col, int? studentId) async {
    try {
      await _repository.updateSeat(classId, row, col, studentId);
      await loadSeating();
    } catch (e) {
      rethrow;
    }
  }
}
