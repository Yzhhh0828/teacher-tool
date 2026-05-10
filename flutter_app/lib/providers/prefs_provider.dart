import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/prefs_service.dart';

/// Singleton [PrefsService] override-able for tests.
///
/// We seed it with a non-functional placeholder; `main()` overrides this
/// before [runApp] using the awaited [PrefsService.create] result.
final prefsServiceProvider = Provider<PrefsService>((ref) {
  throw UnimplementedError(
    'prefsServiceProvider must be overridden in main() before use',
  );
});
