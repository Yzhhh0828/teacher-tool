import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

final dashboardProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, classId) async {
  final api = ref.read(apiClientProvider);
  final resp = await api.get('/dashboard/class/$classId');
  return Map<String, dynamic>.from(resp.data as Map);
});
