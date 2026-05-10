import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/behavior.dart';
import '../data/repositories/behavior_repository.dart';
import 'auth_provider.dart';

final behaviorRepositoryProvider = Provider((ref) => BehaviorRepository(ref.read(apiClientProvider)));

// ─── Categories ─────────────────────────────────────────────────────────────

final behaviorCategoriesProvider = StateNotifierProvider.family<
    BehaviorCategoriesNotifier, AsyncValue<List<BehaviorCategory>>, int>(
  (ref, classId) => BehaviorCategoriesNotifier(ref.read(behaviorRepositoryProvider), classId),
);

class BehaviorCategoriesNotifier extends StateNotifier<AsyncValue<List<BehaviorCategory>>> {
  final BehaviorRepository _repo;
  final int classId;

  BehaviorCategoriesNotifier(this._repo, this.classId) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.getCategories(classId));
  }

  Future<void> createCategory({
    required String name,
    required String icon,
    required double score,
  }) async {
    await _repo.createCategory(classId, name: name, icon: icon, score: score);
    await load();
  }

  Future<void> deleteCategory(int categoryId) async {
    await _repo.deleteCategory(categoryId);
    await load();
  }
}

// ─── Records (timeline) ─────────────────────────────────────────────────────

final behaviorRecordsProvider = StateNotifierProvider.family<
    BehaviorRecordsNotifier, AsyncValue<List<BehaviorRecord>>, int>(
  (ref, classId) => BehaviorRecordsNotifier(ref.read(behaviorRepositoryProvider), classId),
);

class BehaviorRecordsNotifier extends StateNotifier<AsyncValue<List<BehaviorRecord>>> {
  final BehaviorRepository _repo;
  final int classId;

  BehaviorRecordsNotifier(this._repo, this.classId) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.getClassRecords(classId));
  }

  Future<List<BehaviorRecord>> addRecords({
    required List<int> studentIds,
    required int categoryId,
    String? note,
  }) async {
    final records = await _repo.createRecords(
      classId,
      studentIds: studentIds,
      categoryId: categoryId,
      note: note,
    );
    await load();
    return records;
  }

  Future<void> deleteRecord(int recordId) async {
    await _repo.deleteRecord(recordId);
    await load();
  }
}

// ─── Leaderboard ────────────────────────────────────────────────────────────

final behaviorLeaderboardProvider = StateNotifierProvider.family<
    LeaderboardNotifier, AsyncValue<List<StudentScore>>, int>(
  (ref, classId) => LeaderboardNotifier(ref.read(behaviorRepositoryProvider), classId),
);

class LeaderboardNotifier extends StateNotifier<AsyncValue<List<StudentScore>>> {
  final BehaviorRepository _repo;
  final int classId;

  LeaderboardNotifier(this._repo, this.classId) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.getLeaderboard(classId));
  }
}
