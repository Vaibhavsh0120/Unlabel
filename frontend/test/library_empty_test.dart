import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/app/unlabel_theme.dart';
import 'package:unlabel/core/storage/local_store.dart';
import 'package:unlabel/features/scanner/presentation/library_page.dart';

class _EmptyPreferences implements PreferencesAdapter {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> remove(String key) async {}
}

void main() {
  for (final saved in [false, true]) {
    for (final brightness in Brightness.values) {
      for (final width in [320.0, 390.0, 428.0, 1440.0]) {
        for (final scale in [1.0, 2.0]) {
          testWidgets(
            '${saved ? 'Saved' : 'History'} empty page uses its artwork and lookup at $width ${scale}x $brightness',
            (tester) async {
              tester.view.physicalSize = Size(width, 900);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              var lookups = 0;
              var changes = 0;
              var reports = 0;
              await tester.pumpWidget(
                MaterialApp(
                  theme: UnlabelTheme.forBrightness(brightness),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      disableAnimations: true,
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: LibraryPage(
                      saved: saved,
                      store: LocalStore(preferences: _EmptyPreferences()),
                      onOpenReport: (_) => reports++,
                      onLookup: () => lookups++,
                      onChanged: () => changes++,
                      refreshKey: 0,
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              final headline = find.text(
                saved ? 'Keep a useful label close' : 'No labels viewed yet',
              );
              expect(headline, findsOneWidget);
              final message = find.text(
                saved ? 'Open a report and choose Save to find it here later.' : 'Scan a barcode or photograph a label to start your history.',
              );
              final illustration = find.descendant(
                of: find.byType(LibraryEmptyState),
                matching: find.byType(Image),
              );
              final image = tester.widget<Image>(illustration);
              expect(
                (image.image as AssetImage).assetName,
                saved
                    ? 'assets/artwork/saved-empty.webp'
                    : 'assets/artwork/history-empty.webp',
              );
              expect(image.excludeFromSemantics, isTrue);
              final lookup = find.widgetWithText(
                FilledButton,
                'Look up a product',
              );
              final cardBounds = tester.getRect(find.byType(LibraryEmptyState));
              final headlineBounds = tester.getRect(headline);
              final messageBounds = tester.getRect(message);
              final imageBounds = tester.getRect(illustration);
              final actionBounds = tester.getRect(lookup);
              for (final bounds in [
                headlineBounds,
                messageBounds,
                imageBounds,
                actionBounds,
              ]) {
                expect(bounds.left, greaterThanOrEqualTo(cardBounds.left));
                expect(bounds.right, lessThanOrEqualTo(cardBounds.right));
                expect(bounds.top, greaterThanOrEqualTo(cardBounds.top));
                expect(bounds.bottom, lessThanOrEqualTo(cardBounds.bottom));
              }
              if (width < 560) {
                expect(actionBounds.left, closeTo(headlineBounds.left, 1));
                expect(
                  actionBounds.top,
                  greaterThanOrEqualTo(imageBounds.bottom + 20),
                );
                expect(imageBounds.center.dx, closeTo(cardBounds.center.dx, 1));
                expect(
                  imageBounds.top,
                  greaterThanOrEqualTo(messageBounds.bottom + 12),
                );
              }
              await tester.ensureVisible(lookup);
              await tester.pumpAndSettle();
              expect(tester.getSize(lookup).height, greaterThanOrEqualTo(48));
              await tester.tap(lookup);
              await tester.pump();
              expect(lookups, 1);
              expect(changes, 0);
              expect(reports, 0);
              expect(tester.takeException(), isNull);
              await tester.pumpWidget(const SizedBox.shrink());
            },
          );
        }
      }
    }
  }
}
