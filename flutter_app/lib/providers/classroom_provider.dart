import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/classroom_repository.dart';
import 'auth_provider.dart';

final classroomRepositoryProvider = Provider(
  (ref) => ClassroomRepository(ref.read(apiClientProvider)),
);
