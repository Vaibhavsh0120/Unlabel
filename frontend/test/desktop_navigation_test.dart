import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/app/unlabel_theme.dart';
import 'package:unlabel/features/scanner/presentation/desktop_navigation.dart';

void main() {
  for (final height in [730.0, 941.0, 1117.0]) {
    testWidgets('all sidebar destinations remain visible at $height px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(1440, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final visited = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: UnlabelTheme.forBrightness(Brightness.light),
          home: Scaffold(
            body: DesktopNavigation(
              selectedIndex: 0,
              onSelect: (index) => visited.add('$index'),
              onHistory: () => visited.add('history'),
              onInsights: () => visited.add('insights'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var index = 0; index < 6; index++) {
        final item = find.byKey(Key('desktop-nav-$index'));
        final rect = tester.getRect(item);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(height));
        await tester.tap(item);
      }
      final footer = tester.getRect(
        find.byKey(const Key('desktop-sidebar-footer')),
      );
      expect(
        footer.top,
        greaterThanOrEqualTo(
          tester.getRect(find.byKey(const Key('desktop-nav-5'))).bottom,
        ),
      );
      expect(visited, ['0', '1', '2', '3', 'history', 'insights']);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('short window and large text keep every destination reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var insights = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: UnlabelTheme.forBrightness(Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: DesktopNavigation(
            selectedIndex: 0,
            onSelect: (_) {},
            onHistory: () {},
            onInsights: () => insights++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final last = find.byKey(const Key('desktop-nav-5'));
    await tester.ensureVisible(last);
    await tester.pumpAndSettle();
    await tester.tap(last);
    expect(insights, 1);
    expect(tester.takeException(), isNull);
  });
}
