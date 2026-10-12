import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/app/not_found_page.dart';
import 'package:unlabel/app/unlabel_theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'missing page recovery remains reachable with large text $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var visits = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: UnlabelTheme.forBrightness(brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(body: NotFoundPage(onHome: () => visits++)),
          ),
        );
        await tester.pumpAndSettle();
        final home = find.widgetWithText(FilledButton, 'Go to Home');
        await tester.ensureVisible(home);
        await tester.pumpAndSettle();
        await tester.tap(home);
        expect(visits, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
