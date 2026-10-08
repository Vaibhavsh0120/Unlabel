import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/app/unlabel_theme.dart';
import 'package:unlabel/features/scanner/presentation/mobile_navigation.dart';

Future<void> pumpNav(
  WidgetTester tester,
  List<int> selected, {
  int index = 0,
  TextDirection direction = TextDirection.ltr,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: UnlabelTheme.forBrightness(Brightness.light),
      home: Directionality(
        textDirection: direction,
        child: Scaffold(
          bottomNavigationBar: MobileNavigation(
            selectedIndex: index,
            onDestinationSelected: selected.add,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Offset tabCenter(WidgetTester tester, int index) =>
    tester.getCenter(find.byKey(Key('mobile-nav-$index')));

Rect pill(WidgetTester tester) =>
    tester.getRect(find.byKey(const Key('navigation-active-indicator')));

void main() {
  testWidgets('pill follows a quick drag continuously and commits on release', (
    tester,
  ) async {
    final selected = <int>[];
    await pumpNav(tester, selected);
    final gesture = await tester.startGesture(tabCenter(tester, 0));
    await gesture.moveBy(const Offset(24, 0));
    await tester.pump();
    final between = (tabCenter(tester, 1) + tabCenter(tester, 2)) / 2;
    await gesture.moveTo(between);
    await tester.pump();
    expect(selected, isEmpty);
    expect(pill(tester).center.dx, closeTo(between.dx, 1));
    await gesture.moveTo(tabCenter(tester, 2));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(selected, [2]);
  });

  testWidgets('quick drag cancellation returns to the selected tab', (
    tester,
  ) async {
    final selected = <int>[];
    await pumpNav(tester, selected, index: 3);
    final original = pill(tester);
    final gesture = await tester.startGesture(tabCenter(tester, 3));
    await gesture.moveBy(const Offset(-24, 0));
    await gesture.moveTo(tabCenter(tester, 1));
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(selected, isEmpty);
    expect(pill(tester).left, closeTo(original.left, 1));
  });

  testWidgets('active drag clamps at the edge and selects once', (
    tester,
  ) async {
    final selected = <int>[];
    await pumpNav(tester, selected);
    final gesture = await tester.startGesture(tabCenter(tester, 0));
    await gesture.moveBy(const Offset(24, 0));
    await gesture.moveTo(Offset(600, tabCenter(tester, 3).dy));
    await tester.pump();
    expect(pill(tester).center.dx, closeTo(tabCenter(tester, 3).dx, 1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(selected, [3]);
  });

  testWidgets('drag starts only on active pill; ordinary taps still select', (
    tester,
  ) async {
    final selected = <int>[];
    await pumpNav(tester, selected);
    final gesture = await tester.startGesture(tabCenter(tester, 1));
    await gesture.moveBy(const Offset(24, 0));
    await gesture.moveTo(tabCenter(tester, 3));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(selected, isEmpty);
    await tester.tap(find.byKey(const Key('mobile-nav-1')));
    await tester.pumpAndSettle();
    expect(selected, [1]);
  });

  testWidgets('quick RTL drag chooses logical tab without reversing targets', (
    tester,
  ) async {
    final selected = <int>[];
    await pumpNav(tester, selected, direction: TextDirection.rtl);
    final gesture = await tester.startGesture(tabCenter(tester, 0));
    await gesture.moveBy(const Offset(-24, 0));
    await gesture.moveTo(tabCenter(tester, 2));
    await tester.pump();
    expect(pill(tester).center.dx, closeTo(tabCenter(tester, 2).dx, 1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(selected, [2]);
  });
}
