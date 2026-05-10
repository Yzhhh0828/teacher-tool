import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/seating_repository.dart';
import '../data/models/seating.dart';
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
    final seating = await _repository.createOrUpdateSeating(classId, rows, cols);
    state = AsyncValue.data(seating);
  }

  Future<void> shuffleSeats() async {
    final seating = await _repository.shuffleSeats(classId);
    state = AsyncValue.data(seating);
  }

  Future<void> updateSeat(int row, int col, int? studentId) async {
    await _repository.updateSeat(classId, row, col, studentId);
    await loadSeating();
  }

  /// Bulk save the entire seats grid (used by drag-and-drop).
  Future<void> saveSeats(List<List<int?>> seats, {int? rows, int? cols}) async {
    final current = state.valueOrNull;
    final r = rows ?? current?.rows ?? 6;
    final c = cols ?? current?.cols ?? 8;
    final seating = await _repository.saveSeating(classId, r, c, seats);
    state = AsyncValue.data(seating);
  }

  /// Apply a named layout to the active seating.
  Future<void> applyLayout(int layoutId) async {
    final seating = await _repository.applyLayout(layoutId);
    state = AsyncValue.data(seating);
  }
}

// ── Layout list provider ────────────────────────────────────────────────

final seatingLayoutsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, classId) async {
  final repo = ref.read(seatingRepositoryProvider);
  return repo.listLayouts(classId);
});
