import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teacher_tool/core/services/prefs_service.dart';
import 'package:teacher_tool/providers/prefs_provider.dart';
import 'package:teacher_tool/ui/screens/home/widgets/mood_quote_card.dart';

Widget _wrap(Widget child, ProviderContainer container) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 400, child: child),
        ),
      ),
    );

Future<ProviderContainer> _makeContainer({
  Map<String, Object> initialPrefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(initialPrefs);
  final prefs = await PrefsService.create();
  return ProviderContainer(overrides: [
    prefsServiceProvider.overrideWithValue(prefs),
  ]);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('renders 5 mood emojis and a quote line', (tester) async {
    final c = await _makeContainer();
    addTearDown(c.dispose);

    await tester.pumpWidget(
      _wrap(const MoodQuoteCard(accent: Colors.orange), c),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('心情速记'), findsOneWidget);
    expect(find.text('今日金句'), findsOneWidget);
    // The 5 mood labels exist.
    for (final label in ['元气满满', '挺好的', '一般般', '有点累', '想睡觉']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('tapping a mood persists it via PrefsService', (tester) async {
    final c = await _makeContainer();
    addTearDown(c.dispose);
    final prefs = c.read(prefsServiceProvider);
    expect(prefs.moodFor(DateTime.now()), isNull);

    await tester.pumpWidget(
      _wrap(const MoodQuoteCard(accent: Colors.orange), c),
    );
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('元气满满'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(prefs.moodFor(DateTime.now()), 'happy');
    expect(find.text('已记录今日心情'), findsOneWidget);
  });

  testWidgets('quote-of-the-day is deterministic for the same date',
      (tester) async {
    final c = await _makeContainer();
    addTearDown(c.dispose);

    await tester.pumpWidget(
      _wrap(const MoodQuoteCard(accent: Colors.orange), c),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // Capture the displayed quote — it should remain stable across rebuilds
    // for the same calendar day.
    final quoteFinder = find.byWidgetPredicate(
      (w) => w is Text &&
          (w.style?.fontStyle == FontStyle.italic) &&
          (w.data ?? '').isNotEmpty,
    );
    expect(quoteFinder, findsOneWidget);
    final firstQuote = (quoteFinder.evaluate().first.widget as Text).data;

    // Pump again — should still show the same quote.
    await tester.pump(const Duration(milliseconds: 200));
    final secondQuote = (quoteFinder.evaluate().first.widget as Text).data;
    expect(secondQuote, firstQuote);
  });

  testWidgets('add custom quote dialog persists into PrefsService',
      (tester) async {
    final c = await _makeContainer();
    addTearDown(c.dispose);
    final prefs = c.read(prefsServiceProvider);

    await tester.pumpWidget(
      _wrap(const MoodQuoteCard(accent: Colors.orange), c),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // Open dialog via the add icon.
    await tester.tap(find.byTooltip('添加自定义金句'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('添加自定义金句'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '坚持就是胜利');
    await tester.tap(find.text('保存'));
    // Drain dialog dismissal animations to avoid pending-timer assertion.
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(prefs.customQuotes, contains('坚持就是胜利'));
  });
}
