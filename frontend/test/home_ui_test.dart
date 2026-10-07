import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/app/unlabel_theme.dart';
import 'package:unlabel/core/storage/local_store.dart';
import 'package:unlabel/features/scanner/presentation/home_page.dart';
import 'package:unlabel/features/scanner/presentation/insights_page.dart';
import 'package:unlabel/features/scanner/presentation/mobile_navigation.dart';
import 'package:unlabel/features/scanner/presentation/sources_page.dart';
import 'package:unlabel/features/scanner/presentation/ui_components.dart';
import 'package:unlabel/features/scanner/presentation/welcome_page.dart';

class _MemoryPreferences implements PreferencesAdapter {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
}

Widget _app(
  Widget child, {
  Brightness brightness = Brightness.light,
  double scale = 1,
}) => MaterialApp(
  theme: UnlabelTheme.forBrightness(brightness),
  builder: (context, content) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: content!,
  ),
  home: child,
);

HomePage _home({
  VoidCallback? onScan,
  ValueChanged<bool>? onLookup,
  VoidCallback? onCompare,
  ValueChanged<int>? onLibrary,
}) => HomePage(
  store: LocalStore(preferences: _MemoryPreferences()),
  onLookup: onLookup ?? (_) {},
  onEnterLabel: onScan ?? () {},
  onCompare: onCompare ?? () {},
  onOpenReport: (_) {},
  onLibrary: onLibrary ?? (_) {},
  refreshKey: 0,
);

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

  testWidgets('desktop theme preserves full-size semantic button targets', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_app(Scaffold(body: _home())));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byKey(const Key('start-lookup'))).rect.height,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester
            .getSemantics(find.widgetWithText(TextButton, 'See all').first)
            .rect
            .height,
        greaterThanOrEqualTo(48),
      );
    } finally {
      semantics.dispose();
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
    'compact Home reserves live copy over the themed banner background',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          _app(Scaffold(body: _home()), brightness: brightness),
        );
        await tester.pumpAndSettle();
        final hero = tester.getRect(find.byKey(const Key('home-scan-hero')));
        final artwork = tester.getRect(
          find.byKey(const Key('home-hero-background')),
        );
        final scan = tester.getRect(find.byKey(const Key('start-lookup')));
        final actions = tester.getRect(
          find.byKey(const Key('home-actions-grid')),
        );
        expect(hero.left, greaterThanOrEqualTo(16));
        expect(hero.right, lessThanOrEqualTo(374));
        expect(artwork.left, greaterThanOrEqualTo(hero.left));
        expect(artwork.right, lessThanOrEqualTo(hero.right));
        final copy = tester.getRect(find.byKey(const Key('home-scan-copy')));
        expect(copy.right, lessThanOrEqualTo(hero.left + hero.width * .63));
        expect(scan.left - hero.left, greaterThanOrEqualTo(16));
        expect(scan.right, lessThanOrEqualTo(copy.right));
        expect(scan.height, greaterThanOrEqualTo(48));
        final image = tester.widget<Image>(
          find.byKey(const Key('home-hero-background')),
        );
        expect(image.fit, BoxFit.contain);
        expect(
          (image.image as AssetImage).assetName,
          brightness == Brightness.dark
              ? 'assets/artwork/scan-hero-dark.png'
              : 'assets/artwork/scan-hero-light.png',
        );
        expect(actions.top - hero.bottom, greaterThanOrEqualTo(24));
        final barcode = tester.getRect(
          find
              .ancestor(
                of: find.text('Barcode Scan'),
                matching: find.byType(Card),
              )
              .first,
        );
        final compare = tester.getRect(
          find
              .ancestor(
                of: find.text('Compare Products'),
                matching: find.byType(Card),
              )
              .first,
        );
        expect(barcode.top, closeTo(compare.top, .1));
        expect(compare.left - barcode.right, greaterThanOrEqualTo(16));
        expect(barcode.height, greaterThanOrEqualTo(48));
        expect(compare.height, greaterThanOrEqualTo(48));
        for (final row in [
          (barcode, 'Barcode Scan', 'Find a food label'),
          (compare, 'Compare Products', 'Compare the facts'),
        ]) {
          final title = tester.getRect(find.text(row.$2));
          final description = tester.getRect(find.text(row.$3));
          expect(
            (title.top + description.bottom) / 2,
            closeTo(row.$1.center.dy, 1),
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets('narrow enlarged Home stacks art below readable actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(Scaffold(body: _home()), scale: 2));
    await tester.pumpAndSettle();
    final hero = tester.getRect(find.byKey(const Key('home-scan-hero')));
    final artwork = tester.getRect(
      find.byKey(const Key('home-hero-background')),
    );
    final scan = tester.getRect(find.byKey(const Key('start-lookup')));
    expect(artwork.top, greaterThanOrEqualTo(scan.bottom));
    expect(scan.left, greaterThanOrEqualTo(hero.left + 20));
    expect(scan.right, lessThanOrEqualTo(hero.right - 20));
    expect(scan.height, greaterThanOrEqualTo(48));
    await tester.ensureVisible(find.text('Start with the serving size'));
    await tester.pumpAndSettle();
    final insightCopy = tester.getRect(
      find.byKey(const Key('home-insight-copy')),
    );
    final insightArt = tester.getRect(
      find.byKey(const Key('home-insight-art')),
    );
    expect(insightArt.top, greaterThanOrEqualTo(insightCopy.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'home, welcome and navigation adapt to narrow screens and large text',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      for (final width in [320.0, 390.0, 1024.0]) {
        tester.view.physicalSize = Size(width, 844);
        for (final brightness in Brightness.values) {
          for (final scale in [1.0, 2.0]) {
            await tester.pumpWidget(
              _app(
                Scaffold(
                  body: _home(),
                  bottomNavigationBar: MobileNavigation(
                    selectedIndex: 0,
                    onDestinationSelected: (_) {},
                  ),
                ),
                brightness: brightness,
                scale: scale,
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('Scan your\nfood label'), findsOneWidget);
            expect(
              tester.takeException(),
              isNull,
              reason: 'Home $width $brightness scale $scale',
            );
            await tester.pumpWidget(
              _app(
                WelcomePage(onContinue: () {}),
                brightness: brightness,
                scale: scale,
              ),
            );
            await tester.pumpAndSettle();
            expect(
              find.text('Scan food smarter'),
              findsOneWidget,
            );
            expect(
              tester.takeException(),
              isNull,
              reason: 'Welcome $width $brightness scale $scale',
            );
            for (final page in [const InsightsPage(), const SourcesPage()]) {
              await tester.pumpWidget(
                _app(page, brightness: brightness, scale: scale),
              );
              await tester.pumpAndSettle();
              expect(
                tester.takeException(),
                isNull,
                reason: '${page.runtimeType} $width $brightness scale $scale',
              );
              final toggle = find.byType(ExpansionTile);
              await tester.ensureVisible(toggle);
              await tester.tap(toggle);
              await tester.pumpAndSettle();
              expect(
                tester.takeException(),
                isNull,
                reason:
                    'Expanded ${page.runtimeType} $width $brightness scale $scale',
              );
            }
            await tester.pumpWidget(const SizedBox());
          }
        }
      }
    },
  );

  testWidgets('home actions route to their actual destinations', (
    tester,
  ) async {
    var scans = 0;
    var comparisons = 0;
    final lookups = <bool>[];
    final libraries = <int>[];
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: _home(
            onScan: () => scans++,
            onLookup: lookups.add,
            onCompare: () => comparisons++,
            onLibrary: libraries.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-lookup')));
    expect(scans, 1);
    for (final label in [
      'Barcode Scan',
      'Compare Products',
      'Saved Products',
      'History',
    ]) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    expect(lookups, [true]);
    expect(comparisons, 1);
    expect(libraries, [1, 2]);
    await tester.ensureVisible(find.text('Start with the serving size'));
    await tester.tap(find.text('Start with the serving size'));
    await tester.pumpAndSettle();
    expect(find.text('Label tip'), findsOneWidget);
    expect(find.text('All label tips'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Know where facts come from'));
    await tester.tap(find.text('Know where facts come from'));
    await tester.pumpAndSettle();
    expect(find.byType(SourcesPage), findsOneWidget);
  });

  testWidgets(
    'tip carousel is manual, swipes through different pictures and opens the chosen tip',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(Scaffold(body: _home())));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 12));
      expect(find.text('Start with the serving size'), findsOneWidget);
      expect(find.byKey(const Key('insight-next')), findsNothing);
      expect(find.byKey(const Key('insight-previous')), findsNothing);
      expect(find.byKey(const Key('insight-pause')), findsNothing);
      final assets = <String>{};
      for (var index = 0; index < 4; index++) {
        assets.add(
          tester
              .widget<CornerArtwork>(find.byKey(const Key('home-insight-art')))
              .asset,
        );
        if (index < 3) {
          await tester.drag(
            find.byKey(const Key('home-insight-card')),
            const Offset(-220, 0),
          );
          await tester.pumpAndSettle();
        }
      }
      expect(assets.length, 4);
      expect(find.text('Total sugar and added sugar differ'), findsOneWidget);
      await tester.tap(find.byKey(const Key('home-insight-card')));
      await tester.pumpAndSettle();
      expect(find.text('Label tip'), findsOneWidget);
      expect(
        find.text(
          'Total sugar can include naturally occurring sugar and added sugar. Read each declared row separately.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('All label tips'));
      await tester.pumpAndSettle();
      expect(find.text('Label Insights'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'tip carousel never advances automatically and supports keyboard selection',
    (tester) async {
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures();
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      await tester.pumpWidget(_app(Scaffold(body: _home())));
      await tester.pump();
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Start with the serving size'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 30));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Start with the serving size'), findsOneWidget);
      final focus = tester
          .widget<Focus>(find.byKey(const Key('insight-keyboard-focus')))
          .focusNode!;
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Compare the same amount'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Start with the serving size'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'tip carousel exposes adjustable screen-reader actions and RTL swipes',
    (tester) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _app(
          Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: _home()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final node = tester.getSemantics(
        find.byKey(const Key('insight-adjustable')),
      );
      expect(
        node.getSemanticsData().hasAction(ui.SemanticsAction.increase),
        isTrue,
      );
      expect(
        node.getSemanticsData().hasAction(ui.SemanticsAction.decrease),
        isTrue,
      );
      tester.binding.performSemanticsAction(
        ui.SemanticsActionEvent(
          type: ui.SemanticsAction.increase,
          viewId: tester.view.viewId,
          nodeId: node.id,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Compare the same amount'), findsOneWidget);
      await tester.drag(
        find.byKey(const Key('home-insight-card')),
        const Offset(220, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Missing does not mean zero'), findsOneWidget);
      tester.binding.performSemanticsAction(
        ui.SemanticsActionEvent(
          type: ui.SemanticsAction.decrease,
          viewId: tester.view.viewId,
          nodeId: tester
              .getSemantics(find.byKey(const Key('insight-adjustable')))
              .id,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Compare the same amount'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
    },
  );

  testWidgets('welcome starts the app without an account action', (
    tester,
  ) async {
    var continued = false;
    await tester.pumpWidget(
      _app(WelcomePage(onContinue: () => continued = true)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('welcome-continue')));
    expect(
      tester.getSize(find.byKey(const Key('welcome-continue'))).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.byKey(const Key('welcome-continue')));
    expect(continued, isTrue);
  });

  testWidgets('all four navigation targets are accessible and actionable', (
    tester,
  ) async {
    final selected = <int>[];
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        Scaffold(
          bottomNavigationBar: MobileNavigation(
            selectedIndex: 2,
            onDestinationSelected: selected.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var index = 0; index < 4; index++) {
      final target = find.byKey(Key('mobile-nav-$index'));
      final size = tester.getSize(target);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      await tester.tap(target);
    }
    expect(selected, [0, 1, 2, 3]);
    expect(find.byKey(const Key('mobile-nav-4')), findsNothing);
    expect(find.text('Profile'), findsNothing);
    expect(find.bySemanticsLabel('Compare'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
    'holding active navigation slides without navigating until release',
    (tester) async {
      final selected = <int>[];
      await tester.pumpWidget(
        _app(
          Scaffold(
            bottomNavigationBar: MobileNavigation(
              selectedIndex: 0,
              onDestinationSelected: selected.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final initial = tester.getRect(
        find.byKey(const Key('navigation-active-indicator')),
      );
      final target = tester.getCenter(find.byKey(const Key('mobile-nav-2')));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('mobile-nav-0'))),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(target);
      await tester.pump();
      expect(selected, isEmpty);
      final moved = tester.getRect(
        find.byKey(const Key('navigation-active-indicator')),
      );
      expect(moved.left, greaterThan(initial.left));
      expect(moved.center.dx, closeTo(target.dx, 1));
      final draggedIcon = tester.getRect(
        find.byKey(const Key('navigation-dragged-icon')),
      );
      expect(draggedIcon.center.dx, closeTo(target.dx, 1));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(selected, [2]);
      expect(find.byKey(const Key('navigation-dragged-icon')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cancelled navigation hold returns indicator and RTL commits logical slot',
    (tester) async {
      final selected = <int>[];
      await tester.pumpWidget(
        _app(
          Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              bottomNavigationBar: MobileNavigation(
                selectedIndex: 0,
                onDestinationSelected: selected.add,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final initial = tester.getRect(
        find.byKey(const Key('navigation-active-indicator')),
      );
      var gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('mobile-nav-0'))),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(
        tester.getCenter(find.byKey(const Key('mobile-nav-3'))),
      );
      await tester.pump();
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(selected, isEmpty);
      expect(
        tester
            .getRect(find.byKey(const Key('navigation-active-indicator')))
            .left,
        closeTo(initial.left, 1),
      );
      gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('mobile-nav-0'))),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(
        tester.getCenter(find.byKey(const Key('mobile-nav-1'))),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(selected, [1]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('source website action copies the displayed official URL', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
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
    await tester.pumpWidget(_app(const SourcesPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read source details'));
    await tester.pumpAndSettle();
    final copy = find.text('Copy website link').first;
    await tester.ensureVisible(copy);
    await tester.tap(copy);
    await tester.pumpAndSettle();
    expect(copied, 'https://world.openfoodfacts.org/');
    expect(find.text('Source link copied'), findsOneWidget);
  });
}
