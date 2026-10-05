import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/app/unlabel_app.dart';

void main() {
  testWidgets('starter remains usable across target sizes and themes', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    for (final size in [
      const Size(390, 844),
      const Size(844, 390),
      const Size(768, 1024),
      const Size(1024, 768),
      const Size(1440, 900),
      const Size(1728, 1117),
    ]) {
      for (final brightness in Brightness.values) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        await tester.pumpWidget(const UnlabelApp());
        await tester.pumpAndSettle();
        expect(find.text('Label Padhega India'), findsOneWidget);
        expect(find.text('Coming to Unlabel'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final context = tester.element(find.text('Label Padhega India'));
        expect(Theme.of(context).brightness, brightness);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });

  testWidgets('enlarged text keeps lower content reachable on small screens', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = 2;

    for (final size in [const Size(320, 568), const Size(568, 320)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const UnlabelApp());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final context = tester.element(find.text('Label Padhega India'));
      expect(MediaQuery.textScalerOf(context).scale(10), 20);
      final scrollable = find.byType(Scrollable);
      final viewport = tester.getRect(find.byType(SingleChildScrollView));

      for (final text in [
        'Understand every ingredient',
        'Read simple explanations in English or Hindi.',
        'Preview only. No food analysis yet.',
      ]) {
        final target = find.text(text);
        await tester.scrollUntilVisible(
          target.hitTestable(),
          150,
          scrollable: scrollable,
        );
        await tester.pumpAndSettle();
        expect(target.hitTestable(), findsOneWidget);
        final bounds = tester.getRect(target);
        expect(bounds.left, greaterThanOrEqualTo(viewport.left));
        expect(bounds.right, lessThanOrEqualTo(viewport.right));
        expect(bounds.top, greaterThanOrEqualTo(viewport.top));
        expect(bounds.bottom, lessThanOrEqualTo(viewport.bottom));
        expect(tester.takeException(), isNull);
      }

      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('appearance selection overrides system preference', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(const UnlabelApp());
    await tester.tap(find.byKey(const Key('theme-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark').last);
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Label Padhega India'));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(tester.takeException(), isNull);
  });
}
