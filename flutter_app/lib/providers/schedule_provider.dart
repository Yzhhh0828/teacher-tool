import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/schedule.dart';
import '../../data/repositories/schedule_repository.dart';
import 'auth_provider.dart';

final scheduleRepositoryProvider = Provider(
  (ref) => ScheduleRepository(ref.read(apiClientProvider)),
);

final scheduleListProvider = StateNotifierProvider.family<
    ScheduleListNotifier,
    AsyncValue<List<ScheduleModel>>,
    int>((ref, classId) {
  return ScheduleListNotifier(ref.read(scheduleRepositoryProvider), classId);
});

class ScheduleListNotifier extends StateNotifier<AsyncValue<List<ScheduleModel>>> {
  final ScheduleRepository _repository;
  final int classId;

  ScheduleListNotifier(this._repository, this.classId)
      : super(const AsyncValue.loading()) {
    loadSchedules();
  }

  Future<void> loadSchedules() async {
    state = const AsyncValue.loading();
    try {
      final schedules = await _repository.getSchedules(classId);
      state = AsyncValue.data(schedules);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createSchedule(ScheduleModel schedule) async {
    await _repository.createSchedule(schedule);
    await loadSchedules();
  }

  Future<void> deleteSchedule(int scheduleId) async {
    await _repository.deleteSchedule(scheduleId);
    await loadSchedules();
  }
}
