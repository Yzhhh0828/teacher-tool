import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/analytics_repository.dart';
import 'auth_provider.dart';

final analyticsRepositoryProvider = Provider(
  (ref) => AnalyticsRepository(ref.read(apiClientProvider)),
);

// All analytics providers auto-dispose so that old exam distributions,
// student trend caches and one-off compare queries do not pile up in
// memory as the user clicks through analytics drilldowns.
final classOverviewProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, int>(
  (ref, classId) => ref.read(analyticsRepositoryProvider).classOverview(classId),
);

final classCompareProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ({int classId, String? subject})>(
  (ref, args) => ref
      .read(analyticsRepositoryProvider)
      .classCompare(args.classId, subject: args.subject),
);

final examDistributionProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, int>(
  (ref, examId) =>
      ref.read(analyticsRepositoryProvider).examDistribution(examId),
);

final studentTrendProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, int>(
  (ref, studentId) =>
      ref.read(analyticsRepositoryProvider).studentTrend(studentId),
);
