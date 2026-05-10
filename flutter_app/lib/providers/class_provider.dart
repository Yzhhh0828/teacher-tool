import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/class_model.dart';
import '../../data/repositories/class_repository.dart';
import '../core/services/prefs_service.dart';
import 'auth_provider.dart';
import 'prefs_provider.dart';

final classRepositoryProvider =
    Provider((ref) => ClassRepository(ref.read(apiClientProvider)));

final classListProvider = StateNotifierProvider<ClassListNotifier,
    AsyncValue<List<ClassModel>>>((ref) {
  // Reload class list whenever login status flips (logout clears it,
  // re-login fetches fresh data tied to the new account).
  ref.listen<AuthState>(authStateProvider, (prev, next) {
    if (prev?.isLoggedIn != next.isLoggedIn) {
      ref.invalidateSelf();
    }
  });
  return ClassListNotifier(ref.read(classRepositoryProvider));
});

/// Currently-selected class. Persisted via [PrefsService] so it survives a
/// page refresh / cold restart. Memory state is reset on logout via
/// [classAutoSelectProvider].
final currentClassProvider =
    StateNotifierProvider<CurrentClassNotifier, ClassModel?>((ref) {
  return CurrentClassNotifier(ref.read(prefsServiceProvider));
});

class CurrentClassNotifier extends StateNotifier<ClassModel?> {
  final PrefsService _prefs;
  CurrentClassNotifier(this._prefs) : super(null);

  /// Persisted last selection (id only). Read at boot to restore the right
  /// class once the list arrives.
  int? get persistedId => _prefs.currentClassId;

  Future<void> select(ClassModel? cls) async {
    state = cls;
    await _prefs.setCurrentClassId(cls?.id);
  }
}

/// Side-effect provider that keeps [currentClassProvider] in sync with the
/// loaded class list. Auto-restores the persisted selection if present;
/// otherwise picks the first class. Reverts to null when the list empties
/// or the user logs out.
final classAutoSelectProvider = Provider<void>((ref) {
  // Wipe in-memory selection on logout so the next login starts fresh.
  ref.listen<AuthState>(authStateProvider, (prev, next) {
    if (prev?.isLoggedIn == true && next.isLoggedIn == false) {
      // Reach for .state directly to avoid touching prefs (already cleared).
      ref.read(currentClassProvider.notifier).state = null;
    }
  });
  ref.listen<AsyncValue<List<ClassModel>>>(classListProvider, (prev, next) {
    next.whenData((list) {
      final notifier = ref.read(currentClassProvider.notifier);
      final cur = ref.read(currentClassProvider);
      if (list.isEmpty) {
        if (cur != null) notifier.select(null);
        return;
      }
      // Restore persisted selection if it still exists in the list.
      if (cur == null) {
        final pid = notifier.persistedId;
        ClassModel pick;
        if (pid != null) {
          pick = list.firstWhere(
            (c) => c.id == pid,
            orElse: () => list.first,
          );
        } else {
          pick = list.first;
        }
        notifier.select(pick);
        return;
      }
      // Replace stale model (e.g. after rename) and fallback if deleted.
      final match = list.where((c) => c.id == cur.id).toList();
      if (match.isEmpty) {
        notifier.select(list.first);
      } else if (!identical(match.first, cur)) {
        notifier.select(match.first);
      }
    });
  }, fireImmediately: true);
});

class ClassListNotifier
    extends StateNotifier<AsyncValue<List<ClassModel>>> {
  final ClassRepository _repository;

  ClassListNotifier(this._repository)
      : super(const AsyncValue.loading()) {
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
