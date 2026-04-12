import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/api_client.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/models/class_model.dart';
import 'auth_provider.dart';

final classRepositoryProvider = Provider((ref) => ClassRepository(ref.read(apiClientProvider)));

final classListProvider = StateNotifierProvider<ClassListNotifier, AsyncValue<List<ClassModel>>>((ref) {
  return ClassListNotifier(ref.read(classRepositoryProvider));
});

final currentClassProvider = StateProvider<ClassModel?>((ref) => null);

class ClassListNotifier extends StateNotifier<AsyncValue<List<ClassModel>>> {
  final ClassRepository _repository;

  ClassListNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadClasses();
  }

  Future<void> loadClasses() async {
    state = const AsyncValue.loading();
    try {
      final classes = await _repository.getClasses();
      state = AsyncValue.data(classes);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createClass(String name, String grade) async {
    try {
      await _repository.createClass(name, grade);
      await loadClasses();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteClass(int classId) async {
    try {
      await _repository.deleteClass(classId);
      await loadClasses();
    } catch (e) {
      rethrow;
    }
  }
}
