import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/app/unlabel_theme.dart';
import 'package:unlabel/core/storage/local_store.dart';
import 'package:unlabel/features/scanner/presentation/home_page.dart';
import 'package:unlabel/features/scanner/presentation/ui_components.dart';

class _Preferences implements PreferencesAdapter {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> remove(String key) async {}
}

Future<void> _pumpHome(
  WidgetTester tester, {
  required VoidCallback onScan,
  Brightness brightness = Brightness.light,
  double scale = 1,
  bool desktop = false,
  Size? size,
  ValueChanged<int>? onLibrary,
}) async {
  tester.view.physicalSize =
      size ?? (desktop ? const Size(1440, 730) : const Size(390, 700));
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: UnlabelTheme.forBrightness(brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: HomePage(
          desktop: desktop,
          store: LocalStore(preferences: _Preferences()),
          onLookup: (_) {},
          onEnterLabel: onScan,
          onOpenReport: (_) {},
          onLibrary: onLibrary ?? (_) {},
          onCompare: () {},
          refreshKey: 0,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
  });
  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'mobile recent empty state is compact and actionable $brightness',
      (tester) async {
        var scans = 0;
        await _pumpHome(tester, brightness: brightness, onScan: () => scans++);
        final empty = find.byKey(const Key('mobile-empty-scans'));
        final action = find.byKey(const Key('mobile-empty-start-scan'));
        expect(empty, findsOneWidget);
        expect(tester.getSize(empty).height, inInclusiveRange(130, 160));
        expect(
          find.descendant(of: empty, matching: find.byType(Image)),
          findsNothing,
        );
        expect(
          find.descendant(of: empty, matching: find.byType(CornerArtwork)),
          findsNothing,
        );
        expect(
          find.descendant(
            of: empty,
            matching: find.text('No recent scans yet'),
          ),
          findsOneWidget,
        );
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pump();
        expect(scans, 1);
        expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('mobile recent empty state grows for 2x text $brightness', (
      tester,
    ) async {
      var scans = 0;
      await _pumpHome(
        tester,
        brightness: brightness,
        scale: 2,
        onScan: () => scans++,
      );
      final empty = find.byKey(const Key('mobile-empty-scans'));
      final action = find.byKey(const Key('mobile-empty-start-scan'));
      expect(tester.getSize(empty).height, greaterThan(160));
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pump();
      expect(scans, 1);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [1440.0, 1728.0]) {
    testWidgets(
      'desktop compact artwork keeps copy and actions together at $width',
      (tester) async {
        var scans = 0;
        int? destination;
        await _pumpHome(
          tester,
          desktop: true,
          size: Size(width, 730),
          onScan: () => scans++,
          onLibrary: (index) => destination = index,
        );
        final desktop = find.byKey(const Key('desktop-empty-scans'));
        final art = find.byKey(const Key('desktop-empty-scans-art'));
        final content = find.byKey(const Key('desktop-empty-scans-content'));
        final scan = find.byKey(const Key('desktop-empty-start-scan'));
        expect(desktop, findsOneWidget);
        expect(find.byKey(const Key('mobile-empty-scans')), findsNothing);
        expect(tester.getSize(art), const Size(160, 106));
        expect(tester.getSize(desktop).height, lessThanOrEqualTo(180));
        expect(tester.getRect(content).left - tester.getRect(art).right, 20);
        final illustration = tester.widget<Image>(
          find.descendant(of: desktop, matching: find.byType(Image)),
        );
        expect(
          (illustration.image as AssetImage).assetName,
          'assets/artwork/desktop-empty-scans.png',
        );
        await tester.ensureVisible(scan);
        await tester.tap(scan);
        await tester.pump();
        expect(scans, 1);
        await tester.tap(find.text('Browse saved products'));
        await tester.pump();
        expect(destination, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('desktop recent empty state grows without clipping at 2x text', (
    tester,
  ) async {
    var scans = 0;
    await _pumpHome(tester, desktop: true, scale: 2, onScan: () => scans++);
    final scan = find.byKey(const Key('desktop-empty-start-scan'));
    await tester.ensureVisible(scan);
    await tester.tap(scan);
    await tester.pump();
    expect(scans, 1);
    expect(tester.takeException(), isNull);
  });
}
