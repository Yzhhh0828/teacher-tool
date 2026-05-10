import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teacher_tool/core/services/prefs_service.dart';
import 'package:teacher_tool/data/models/class_model.dart';
import 'package:teacher_tool/data/repositories/class_repository.dart';
import 'package:teacher_tool/providers/class_provider.dart';
import 'package:teacher_tool/providers/prefs_provider.dart';

class _MockClassRepository extends Mock implements ClassRepository {}

ClassModel _cls(int id, String name) => ClassModel(
      id: id,
      name: name,
      grade: '三年级',
      ownerId: 1,
      createdAt: DateTime(2026, 5, 10),
    );

void main() {
  late _MockClassRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = _MockClassRepository();
  });

  Future<ProviderContainer> makeContainer({
    Map<String, Object> initialPrefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(initialPrefs);
    final prefs = await PrefsService.create();
    return ProviderContainer(overrides: [
      prefsServiceProvider.overrideWithValue(prefs),
      classRepositoryProvider.overrideWithValue(repo),
    ]);
  }

  test('CurrentClassNotifier persists id when select() is called', () async {
    final c = await makeContainer();
    addTearDown(c.dispose);
    final n = c.read(currentClassProvider.notifier);

    await n.select(_cls(7, '一班'));
    expect(c.read(currentClassProvider)?.id, 7);
    expect(c.read(prefsServiceProvider).currentClassId, 7);

    await n.select(null);
    expect(c.read(currentClassProvider), isNull);
    expect(c.read(prefsServiceProvider).currentClassId, isNull);
  });

  test('persistedId reflects pre-existing prefs at boot', () async {
    final c = await makeContainer(initialPrefs: {'current_class_id': 99});
    addTearDown(c.dispose);
    expect(c.read(currentClassProvider.notifier).persistedId, 99);
  });

  test('classAutoSelectProvider restores persisted class from list', () async {
    final list = [_cls(1, 'A'), _cls(99, 'B'), _cls(3, 'C')];
    when(() => repo.getClasses()).thenAnswer((_) async => list);

    final c = await makeContainer(initialPrefs: {'current_class_id': 99});
    addTearDown(c.dispose);

    // Activate the auto-select listener.
    c.read(classAutoSelectProvider);
    // Wait for the initial load to complete.
    await c.read(classListProvider.notifier).loadClasses();
    // Pump microtasks.
    await Future<void>.delayed(Duration.zero);

    expect(c.read(currentClassProvider)?.id, 99,
        reason: 'should pick the persisted id, not list.first');
  });

  test('classAutoSelectProvider falls back to first when persisted id missing',
      () async {
    final list = [_cls(1, 'A'), _cls(2, 'B')];
    when(() => repo.getClasses()).thenAnswer((_) async => list);

    final c = await makeContainer(initialPrefs: {'current_class_id': 999});
    addTearDown(c.dispose);
    c.read(classAutoSelectProvider);
    await c.read(classListProvider.notifier).loadClasses();
    await Future<void>.delayed(Duration.zero);

    expect(c.read(currentClassProvider)?.id, 1);
  });

  test('classAutoSelectProvider clears selection when list becomes empty',
      () async {
    when(() => repo.getClasses()).thenAnswer((_) async => [_cls(5, 'Solo')]);

    final c = await makeContainer();
    addTearDown(c.dispose);
    c.read(classAutoSelectProvider);
    await c.read(classListProvider.notifier).loadClasses();
    await Future<void>.delayed(Duration.zero);
    expect(c.read(currentClassProvider)?.id, 5);

    // Class deleted.
    when(() => repo.getClasses()).thenAnswer((_) async => <ClassModel>[]);
    await c.read(classListProvider.notifier).loadClasses();
    await Future<void>.delayed(Duration.zero);
    expect(c.read(currentClassProvider), isNull);
  });
}
