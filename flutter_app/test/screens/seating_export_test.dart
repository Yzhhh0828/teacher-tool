import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_tool/ui/screens/seating/seating_export.dart';

void main() {
  testWidgets('SeatingExporter.capturePng rasterises a RepaintBoundary',
      (tester) async {
    final key = GlobalKey();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: key,
            child: const SizedBox(
              width: 200,
              height: 100,
              child: ColoredBox(color: Color(0xFFFF8800)),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // toImage() needs the real platform dispatcher, so wrap in runAsync.
    final png = await tester.runAsync<List<int>>(
      () => SeatingExporter.capturePng(key, pixelRatio: 1.0),
    );
    expect(png, isNotNull);
    // PNG signature: 0x89 0x50 0x4E 0x47.
    expect(png![0], 0x89);
    expect(png[1], 0x50);
    expect(png[2], 0x4E);
    expect(png[3], 0x47);
    expect(png.length, greaterThan(200));
  });

  testWidgets('SeatingExporter.capturePng throws if boundary not mounted',
      (tester) async {
    final key = GlobalKey();
    expect(
      () => SeatingExporter.capturePng(key),
      throwsA(isA<StateError>()),
    );
  });
}
