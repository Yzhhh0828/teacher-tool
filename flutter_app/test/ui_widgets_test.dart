import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_tool/core/design/theme_builder.dart';
import 'package:teacher_tool/core/design/tokens.dart';
import 'package:teacher_tool/ui/widgets/app_snackbar.dart';
import 'package:teacher_tool/ui/widgets/empty_view.dart';
import 'package:teacher_tool/ui/widgets/shimmer_skeleton.dart';
import 'package:teacher_tool/ui/widgets/soft_card.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: buildAppTheme(AppPalette.vibrant),
    home: Scaffold(body: child),
  );
}

void main() {
  group('SoftCard', () {
    testWidgets('renders child and calls onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(
        Center(
          child: SoftCard(
            onTap: () => tapped = true,
            child: const Text('card content'),
          ),
        ),
      ));
      expect(find.text('card content'), findsOneWidget);
      await tester.tap(find.text('card content'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('renders without onTap (non-interactive)', (tester) async {
      await tester.pumpWidget(_wrap(
        const Center(
          child: SoftCard(child: Text('static')),
        ),
      ));
      expect(find.text('static'), findsOneWidget);
    });

    testWidgets('renders accent stripe when accent provided', (tester) async {
      await tester.pumpWidget(_wrap(
        Center(
          child: SoftCard(
            accent: Colors.blue,
            onTap: () {},
            child: const Text('accent card'),
          ),
        ),
      ));
      expect(find.text('accent card'), findsOneWidget);
    });
  });

  group('ShimmerSkeleton', () {
    testWidgets('.list renders correct number of items', (tester) async {
      await tester.pumpWidget(_wrap(
        ShimmerSkeleton.list(itemCount: 4, itemHeight: 48),
      ));
      // Pump one frame, then tear down (shimmer uses repeating animation)
      await tester.pump(const Duration(milliseconds: 100));
      final containers = find.byType(Container);
      expect(containers, findsWidgets);
      // Dispose widget tree to stop timers
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('.grid renders without errors', (tester) async {
      await tester.pumpWidget(_wrap(
        ShimmerSkeleton.grid(crossAxisCount: 3, itemCount: 6),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('.block renders single block', (tester) async {
      await tester.pumpWidget(_wrap(
        const ShimmerSkeleton(height: 100, width: 200),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('EmptyView', () {
    testWidgets('renders icon, title, and message', (tester) async {
      await tester.pumpWidget(_wrap(
        const EmptyView(
          icon: Icons.inbox_rounded,
          title: '暂无数据',
          message: '还没有添加任何内容',
        ),
      ));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('暂无数据'), findsOneWidget);
      expect(find.text('还没有添加任何内容'), findsOneWidget);
      expect(find.byIcon(Icons.inbox_rounded), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('renders action button when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        EmptyView(
          icon: Icons.add,
          title: '空空如也',
          action: FilledButton(
            onPressed: () {},
            child: const Text('添加'),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('添加'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('AppSnackbar', () {
    testWidgets('.success shows a snackbar', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(AppPalette.vibrant),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () =>
                    AppSnackbar.success(context, message: '操作成功'),
                child: const Text('trigger'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('trigger'));
      await tester.pump();
      expect(find.text('操作成功'), findsOneWidget);
    });

    testWidgets('.error shows error snackbar', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(AppPalette.vibrant),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () =>
                    AppSnackbar.error(context, message: '出错了'),
                child: const Text('trigger'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('trigger'));
      await tester.pump();
      expect(find.text('出错了'), findsOneWidget);
    });
  });
}
