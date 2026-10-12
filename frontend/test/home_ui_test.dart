import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/app/unlabel_theme.dart';
import 'package:unlabel/core/storage/local_store.dart';
import 'package:unlabel/features/scanner/domain/insight_catalogue.dart';
import 'package:unlabel/features/scanner/domain/insight_controller.dart';
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

// Widget tests advance their own lifecycle clock; the catalogue/controller
// suite separately verifies midnight scheduling. Avoid a real midnight timer
// owned outside the widget tree under test.
class _TestInsightController extends InsightController {
  _TestInsightController({super.preferences, super.clock});

  @override
  Future<void> start() => reloadSaved();
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

final _insightDay = DateTime(2026, 10, 9);
final _dailyInsights = InsightCatalogue.daily(_insightDay);

InsightsPage _insightsPage() {
  final controller = _TestInsightController(
    preferences: _MemoryPreferences(),
    clock: () => _insightDay,
  );
  addTearDown(controller.dispose);
  return InsightsPage(controller: controller);
}

HomePage _home({
  bool desktop = false,
  VoidCallback? onScan,
  ValueChanged<bool>? onLookup,
  VoidCallback? onCompare,
  ValueChanged<int>? onLibrary,
  VoidCallback? onInsights,
  InsightController? insightController,
}) {
  final store = LocalStore(preferences: _MemoryPreferences());
  final controller =
      insightController ??
      _TestInsightController(
        preferences: store.preferences,
        clock: () => _insightDay,
      );
  if (insightController == null) addTearDown(controller.dispose);
  return HomePage(
    desktop: desktop,
    store: store,
    insightController: controller,
    onInsights: onInsights,
    onLookup: onLookup ?? (_) {},
    onEnterLabel: onScan ?? () {},
    onCompare: onCompare ?? () {},
    onOpenReport: (_) {},
    onLibrary: onLibrary ?? (_) {},
    refreshKey: 0,
  );
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
      'insight art stays separate from copy across sizes $brightness',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final width in [320.0, 390.0, 768.0, 1024.0, 1440.0, 1728.0]) {
          tester.view.physicalSize = Size(width, 941);
          for (final scale in [1.0, 2.0]) {
            await tester.pumpWidget(
              _app(
                Scaffold(body: _home(desktop: width >= 1024)),
                brightness: brightness,
                scale: scale,
              ),
            );
            await tester.pumpAndSettle();
            await tester.ensureVisible(
              find.byKey(const Key('home-insight-card')),
            );
            final card = tester.getRect(
              find.byKey(const Key('home-insight-card')),
            );
            final copy = tester.getRect(
              find.byKey(const Key('home-insight-copy')),
            );
            final art = tester.getRect(
              find.byKey(const Key('home-insight-art')),
            );
            expect(art.left, greaterThanOrEqualTo(card.left));
            expect(art.right, lessThanOrEqualTo(card.right));
            expect(art.top, greaterThanOrEqualTo(card.top));
            expect(art.bottom, lessThanOrEqualTo(card.bottom));
            expect(art.overlaps(copy), isFalse);
            expect(
              tester.takeException(),
              isNull,
              reason: '$width $brightness scale $scale',
            );
            await tester.pumpWidget(const SizedBox.shrink());
          }
        }
      },
    );
  }

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
              ? 'assets/artwork/scan-hero-dark.webp'
              : 'assets/artwork/scan-hero-light.webp',
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
    await tester.ensureVisible(find.text(_dailyInsights.first.title));
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
            expect(find.text('Scan food smarter'), findsOneWidget);
            expect(
              tester.takeException(),
              isNull,
              reason: 'Welcome $width $brightness scale $scale',
            );
            for (final page in [_insightsPage(), const SourcesPage()]) {
              await tester.pumpWidget(
                _app(page, brightness: brightness, scale: scale),
              );
              await tester.pumpAndSettle();
              expect(
                tester.takeException(),
                isNull,
                reason: '${page.runtimeType} $width $brightness scale $scale',
              );
              if (page is SourcesPage) {
                final toggle = find.byKey(const Key('source-details-facts'));
                await tester.ensureVisible(toggle);
                await tester.tap(toggle);
                await tester.pumpAndSettle();
                expect(
                  tester.takeException(),
                  isNull,
                  reason:
                      'Source details ${page.runtimeType} $width $brightness scale $scale',
                );
                await tester.ensureVisible(find.text('Close'));
                await tester.tap(find.text('Close'));
                await tester.pumpAndSettle();
              }
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
    await tester.ensureVisible(find.text(_dailyInsights.first.title));
    await tester.tap(find.text(_dailyInsights.first.title));
    await tester.pumpAndSettle();
    expect(find.byType(InsightArticlePage), findsOneWidget);
    expect(find.text(_dailyInsights.first.takeaway), findsOneWidget);
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
      expect(find.text(_dailyInsights.first.title), findsOneWidget);
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
      expect(find.text(_dailyInsights.last.title), findsOneWidget);
      await tester.tap(find.byKey(const Key('home-insight-card')));
      await tester.pumpAndSettle();
      expect(find.byType(InsightArticlePage), findsOneWidget);
      for (final section in _dailyInsights.last.sections) {
        expect(find.text(section.heading), findsOneWidget);
        expect(find.text(section.body), findsOneWidget);
      }
      expect(find.text(_dailyInsights.last.takeaway), findsOneWidget);
      expect(find.text('Sources'), findsOneWidget);
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
      expect(find.text(_dailyInsights.first.title), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 30));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 30));
      expect(find.text(_dailyInsights.first.title), findsOneWidget);
      final focus = tester
          .widget<Focus>(find.byKey(const Key('insight-keyboard-focus')))
          .focusNode!;
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text(_dailyInsights[1].title), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text(_dailyInsights.first.title), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('desktop daily dots select four different article artworks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 941);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(Scaffold(body: _home(desktop: true))));
    await tester.pumpAndSettle();
    final assets = <String>{};
    for (var index = 0; index < 4; index++) {
      final dot = find.byKey(Key('insight-page-$index'));
      await tester.ensureVisible(dot);
      expect(tester.getSize(dot).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(dot).height, 28);
      await tester.tap(dot);
      await tester.pumpAndSettle();
      expect(find.text(_dailyInsights[index].title), findsOneWidget);
      expect(tester.widget<Semantics>(dot).properties.selected, true);
      final art = tester.widget<Image>(
        find.byKey(const Key('home-insight-art')),
      );
      expect(art.fit, BoxFit.contain);
      final asset = (art.image as AssetImage).assetName;
      expect(asset, _dailyInsights[index].asset);
      assets.add(asset);
    }
    expect(assets, hasLength(4));
    expect(
      tester.getSize(find.byKey(const Key('home-insight-carousel'))).height -
          tester.getSize(find.byKey(const Key('home-insight-card'))).height,
      32,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('desktop mouse swipe changes the daily fact and its artwork', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 941);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var insightVisits = 0;
    await tester.pumpWidget(
      _app(
        Scaffold(body: _home(desktop: true, onInsights: () => insightVisits++)),
      ),
    );
    await tester.pumpAndSettle();
    final card = find.byKey(const Key('home-insight-card'));
    await tester.ensureVisible(card);
    await tester.drag(
      card,
      const Offset(-220, 0),
      kind: ui.PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(find.text(_dailyInsights[1].title), findsOneWidget);
    final art = tester.widget<Image>(find.byKey(const Key('home-insight-art')));
    expect((art.image as AssetImage).assetName, _dailyInsights[1].asset);
    expect(find.byType(InsightArticlePage), findsNothing);
    expect(insightVisits, 0);
    await tester.drag(
      card,
      const Offset(220, 0),
      kind: ui.PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(find.text(_dailyInsights.first.title), findsOneWidget);
    expect(find.byType(InsightArticlePage), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Home refreshes daily picks on resume without autoplay', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 9, 23, 59);
    final controller = _TestInsightController(
      preferences: _MemoryPreferences(),
      clock: () => now,
    );
    addTearDown(controller.dispose);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _app(Scaffold(body: _home(insightController: controller))),
    );
    await tester.pumpAndSettle();
    final dot = find.byKey(const Key('insight-page-2'));
    await tester.ensureVisible(dot);
    await tester.tap(dot);
    await tester.pumpAndSettle();
    expect(find.text(controller.daily[2].title), findsOneWidget);
    final previous = controller.daily.first.id;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = DateTime(2026, 10, 10, 0, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(controller.daily.first.id, isNot(previous));
    expect(find.text(InsightCatalogue.daily(now).first.title), findsOneWidget);
    await tester.pump(const Duration(seconds: 20));
    expect(find.text(controller.daily.first.title), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Home See all uses the shell Insights callback', (tester) async {
    var visits = 0;
    await tester.pumpWidget(
      _app(Scaffold(body: _home(onInsights: () => visits++))),
    );
    await tester.pumpAndSettle();
    final seeAll = find.widgetWithText(TextButton, 'See all').first;
    await tester.ensureVisible(seeAll);
    await tester.tap(seeAll);
    expect(visits, 1);
    expect(find.byType(InsightsPage), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('daily dots can be activated directly by a screen reader', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final size in [const Size(390, 1200), const Size(1440, 941)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          _app(Scaffold(body: _home(desktop: size.width >= 1200))),
        );
        await tester.pumpAndSettle();
        for (var index = 0; index < 4; index++) {
          final dot = find.byKey(Key('insight-page-$index'));
          await tester.ensureVisible(dot);
          final node = tester.getSemantics(dot);
          expect(
            node.getSemanticsData().hasAction(ui.SemanticsAction.tap),
            isTrue,
            reason: 'Daily dot ${index + 1} at ${size.width}',
          );
          tester.binding.performSemanticsAction(
            ui.SemanticsActionEvent(
              type: ui.SemanticsAction.tap,
              viewId: tester.view.viewId,
              nodeId: node.id,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(_dailyInsights[index].title), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

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
      expect(find.text(_dailyInsights[1].title), findsOneWidget);
      await tester.drag(
        find.byKey(const Key('home-insight-card')),
        const Offset(220, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text(_dailyInsights[2].title), findsOneWidget);
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
      expect(find.text(_dailyInsights[1].title), findsOneWidget);
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
      // Tab icons keep their own positions while the pill follows the finger.
      expect(find.byKey(const Key('mobile-nav-0')), findsOneWidget);
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
    final copy = find.text('Copy website link').first;
    await tester.ensureVisible(copy);
    await tester.tap(copy);
    await tester.pumpAndSettle();
    expect(copied, 'https://world.openfoodfacts.org/');
    expect(find.text('Source link copied'), findsWidgets);
  });
}
