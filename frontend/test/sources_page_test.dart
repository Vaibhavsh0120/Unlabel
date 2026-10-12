import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/app/unlabel_theme.dart';
import 'package:unlabel/features/scanner/presentation/sources_page.dart';

const _ids = ['facts', 'package', 'off', 'fssai', 'codex', 'boundary'];

Widget _app({Brightness brightness = Brightness.light, double scale = 1}) =>
    MaterialApp(
      theme: UnlabelTheme.forBrightness(brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: const SourcesPage(),
    );

void main() {
  testWidgets(
    'six distinct Sources rows fit phones, desktop and enlarged text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final width in [320.0, 390.0, 1440.0, 1728.0]) {
        for (final brightness in Brightness.values) {
          for (final scale in [1.0, 2.0]) {
            tester.view.physicalSize = Size(width, 900);
            await tester.pumpWidget(_app(brightness: brightness, scale: scale));
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$width $brightness $scale',
            );
            expect(find.text('Our Sources'), findsOneWidget);
            expect(find.byType(ExpansionTile), findsNothing);
            final images = tester
                .widgetList<Image>(find.byType(Image))
                .toList();
            expect(images.length, 7);
            expect(
              images
                  .map((image) => (image.image as AssetImage).assetName)
                  .toSet()
                  .length,
              7,
            );
            for (final id in _ids) {
              final card = find.byKey(Key('source-card-$id'));
              final bounds = tester.getRect(card);
              expect(bounds.left, greaterThanOrEqualTo(0));
              expect(bounds.right, lessThanOrEqualTo(width));
              final image = find.descendant(
                of: card,
                matching: find.byType(Image),
              );
              final imageBounds = tester.getRect(image);
              final text = find.descendant(
                of: card,
                matching: find.byType(Text),
              );
              for (final element in text.evaluate()) {
                final box = element.renderObject! as RenderBox;
                expect(
                  (box.localToGlobal(Offset.zero) & box.size).overlaps(
                    imageBounds,
                  ),
                  isFalse,
                  reason: '$id live copy/art overlap at $width $scale',
                );
              }
            }
          }
        }
      }
    },
  );

  testWidgets('every source chevron opens its explanation and can close', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    for (final id in _ids) {
      final button = find.byKey(Key('source-details-$id'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.ensureVisible(find.text('Close'));
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('source detail copy reports success and clipboard failure', (
    tester,
  ) async {
    String? copied;
    var fail = false;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          if (fail) throw PlatformException(code: 'clipboard-unavailable');
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    final details = find.byKey(const Key('source-details-off'));
    await tester.ensureVisible(details);
    await tester.tap(details);
    await tester.pumpAndSettle();
    final copy = find.byKey(const Key('source-copy-off-sheet'));
    await tester.ensureVisible(copy);
    await tester.tap(copy);
    await tester.pumpAndSettle();
    expect(copied, 'https://world.openfoodfacts.org/');
    expect(find.text('Source link copied'), findsWidgets);
    fail = true;
    await tester.tap(copy);
    await tester.pumpAndSettle();
    expect(
      find.text('Could not copy. Select the address to copy it.'),
      findsOneWidget,
    );
    expect(find.byType(SelectableText), findsWidgets);
  });
}
