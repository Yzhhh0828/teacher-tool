import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/analytics_repository.dart';
import 'auth_provider.dart';

final analyticsRepositoryProvider = Provider(
  (ref) => AnalyticsRepository(ref.read(apiClientProvider)),
);

final classOverviewProvider = FutureProvider.family<Map<String, dynamic>, int>(
  (ref, classId) => ref.read(analyticsRepositoryProvider).classOverview(classId),
);

final classCompareProvider = FutureProvider.family<Map<String, dynamic>, ({int classId, String? subject})>(
  (ref, args) => ref.read(analyticsRepositoryProvider).classCompare(args.classId, subject: args.subject),
);

final examDistributionProvider = FutureProvider.family<Map<String, dynamic>, int>(
  (ref, examId) => ref.read(analyticsRepositoryProvider).examDistribution(examId),
);

final studentTrendProvider = FutureProvider.family<Map<String, dynamic>, int>(
  (ref, studentId) => ref.read(analyticsRepositoryProvider).studentTrend(studentId),
);
