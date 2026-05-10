import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_tool/core/design/theme_builder.dart';
import 'package:teacher_tool/core/design/tokens.dart';
import 'package:teacher_tool/ui/widgets/animated_number.dart';
import 'package:teacher_tool/ui/widgets/app_card.dart';
import 'package:teacher_tool/ui/widgets/wheel_picker.dart';

Widget _wrap(Widget child, {AppPalette? palette}) {
  return MaterialApp(
    theme: buildAppTheme(palette ?? AppPalette.mellardGreen),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('AppCard renders its child and reacts to tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(
      Center(
        child: AppCard(
          onTap: () => taps++,
          child: const Text('hello'),
        ),
      ),
    ));
    expect(find.text('hello'), findsOneWidget);
    await tester.tap(find.text('hello'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('GlassPanel renders without overflow', (tester) async {
    await tester.pumpWidget(_wrap(
      const Center(
        child: SizedBox(
          width: 240,
          child: GlassPanel(child: Text('glass')),
        ),
      ),
    ));
    expect(find.text('glass'), findsOneWidget);
  });

  testWidgets('AnimatedNumber tweens to its target value', (tester) async {
    await tester.pumpWidget(_wrap(
      const AnimatedNumber(value: 42, suffix: '%'),
    ));
    await tester.pump(); // start
    await tester.pumpAndSettle(); // animate
    expect(find.text('42%'), findsOneWidget);
  });

  testWidgets('NameWheel cycles labels and lands on the final name',
      (tester) async {
    String? landed;
    await tester.pumpWidget(_wrap(
      NameWheel(
        names: const ['A', 'B', 'C'],
        running: true,
        finalName: 'C',
        onSettled: (n) => landed = n,
        spinDuration: const Duration(milliseconds: 200),
      ),
    ));
    await tester.pump(); // initial frame
    await tester.pump(const Duration(milliseconds: 250)); // past spin
    await tester.pumpAndSettle();
    expect(landed, 'C');
    expect(find.text('C'), findsOneWidget);
  });

  test('AppPalette.byName falls back to vibrant for unknown values', () {
    expect(AppPalette.byName(null).name, 'vibrant');
    expect(AppPalette.byName('mellardGreen').name, 'mellardGreen');
    expect(AppPalette.byName('warmOrange').name, 'warmOrange');
    expect(AppPalette.byName('does-not-exist').name, 'vibrant');
  });

  test('buildAppTheme produces a Material 3 theme keyed by palette', () {
    final green = buildAppTheme(AppPalette.mellardGreen);
    final orange = buildAppTheme(AppPalette.warmOrange);
    expect(green.useMaterial3, isTrue);
    expect(orange.useMaterial3, isTrue);
    // Different palettes must yield different primary colours.
    expect(green.colorScheme.primary, isNot(orange.colorScheme.primary));
  });
}
