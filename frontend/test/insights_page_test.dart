import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/app/unlabel_theme.dart';
import 'package:unlabel/core/storage/local_store.dart';
import 'package:unlabel/features/scanner/domain/insight_controller.dart';
import 'package:unlabel/features/scanner/domain/insight_catalogue.dart';
import 'package:unlabel/features/scanner/presentation/insights_page.dart';

class _MemoryPreferences implements PreferencesAdapter {
  final values = <String, String>{};
  bool failWrite = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    if (failWrite) throw StateError('Unavailable');
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async => values.remove(key);
}

Widget _app(
  Widget page, {
  Brightness brightness = Brightness.light,
  double scale = 1,
}) => MaterialApp(
  theme: UnlabelTheme.forBrightness(brightness),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(disableAnimations: true, textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: page,
);

class _TestController extends InsightController {
  _TestController({required super.preferences})
    : super(clock: () => DateTime(2026, 10, 9));
  // Midnight scheduling is covered by domain tests. This UI fixture uses a
  // fixed date and does not leave an externally owned timer in widget tests.
  @override
  Future<void> start() => reloadSaved();
}

InsightController _controller({_MemoryPreferences? preferences}) =>
    _TestController(preferences: preferences ?? _MemoryPreferences());

void main() {
  for (final width in [1440.0, 1728.0]) {
    testWidgets(
      'desktop daily support cards share natural row height at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = _controller();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _app(
            Scaffold(
              body: Row(
                children: [
                  const SizedBox(width: 240),
                  Expanded(
                    child: InsightsPage(controller: controller, embedded: true),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final cards = controller.daily
            .skip(1)
            .map((article) => find.byKey(Key('insight-card-${article.id}')))
            .toList();
        final heights = cards
            .map((card) => tester.getSize(card).height)
            .toList();
        expect(heights[1], closeTo(heights[0], .01));
        expect(heights[2], closeTo(heights[0], .01));
        final badges = controller.daily
            .skip(1)
            .map(
              (article) =>
                  tester.getRect(find.byKey(Key('insight-read-${article.id}'))),
            )
            .toList();
        expect(badges[1].bottom, closeTo(badges[0].bottom, .01));
        expect(badges[2].bottom, closeTo(badges[0].bottom, .01));
        for (final article in controller.daily.skip(1)) {
          final card = tester.getRect(
            find.byKey(Key('insight-card-${article.id}')),
          );
          expect(
            tester.getRect(find.text(article.summary)).bottom,
            lessThan(card.bottom),
          );
          final badge = tester.getRect(
            find.byKey(Key('insight-read-${article.id}')),
          );
          final image = tester.getRect(
            find.byKey(Key('insight-art-${article.id}')),
          );
          final copy = tester.getRect(
            find.byKey(Key('insight-copy-${article.id}')),
          );
          expect(card.bottom - badge.bottom, closeTo(12, .01));
          expect(image.center.dy, closeTo(copy.center.dy, .01));
          final contentCenter = (card.top + 12 + badge.top - 12) / 2;
          expect(image.center.dy, closeTo(contentCenter, .01));
          expect(
            tester
                .getSize(find.byKey(Key('insight-save-${article.id}')))
                .height,
            greaterThanOrEqualTo(44),
          );
        }
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is AssetImage &&
                (widget.image as AssetImage).assetName ==
                    'assets/artwork/botanical-corner.webp',
          ),
          findsNothing,
        );
        // The additional space on a shorter card remains part of its action.
        await tester.tapAt(
          tester.getRect(cards.last).bottomCenter - const Offset(0, 16),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<InsightArticlePage>(find.byType(InsightArticlePage))
              .article
              .id,
          controller.daily.last.id,
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
        final article = controller.daily[1];
        await tester.tap(find.byKey(Key('insight-save-${article.id}')));
        await tester.pumpAndSettle();
        expect(controller.isSaved(article.id), isTrue);
        await tester.tap(cards.first.first);
        await tester.pumpAndSettle();
        expect(find.byType(InsightArticlePage), findsOneWidget);
        expect(
          tester
              .widget<InsightArticlePage>(find.byType(InsightArticlePage))
              .article
              .id,
          article.id,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('Insights offers a daily feed and topic navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: UnlabelTheme.forBrightness(Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: InsightsPage(preferences: _MemoryPreferences()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Insights'), findsOneWidget);
    expect(find.byKey(const Key('insight-topic-sugar')), findsOneWidget);
    expect(find.byKey(const Key('insight-featured')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('daily articles open, bookmark and appear in saved collection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(InsightsPage(controller: controller)));
    await tester.pumpAndSettle();
    expect(controller.daily.length, 4);
    final first = controller.daily.first;
    await tester.tap(find.byKey(Key('insight-save-${first.id}')).first);
    await tester.pumpAndSettle();
    expect(controller.isSaved(first.id), isTrue);
    expect(find.byKey(const Key('insights-see-saved')), findsOneWidget);
    await tester.tap(find.byKey(const Key('insight-featured')));
    await tester.pumpAndSettle();
    expect(find.byType(InsightArticlePage), findsOneWidget);
    expect(find.text(first.sections.first.heading), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('insights-see-saved')));
    await tester.pumpAndSettle();
    expect(find.text('Saved insights'), findsOneWidget);
    expect(find.text(first.title), findsOneWidget);
    await tester.tap(find.byKey(Key('insight-save-${first.id}')));
    await tester.pumpAndSettle();
    expect(controller.saved, isEmpty);
    expect(find.textContaining('No saved insights yet.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('filters browse full topics and all twenty remain accessible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(InsightsPage(controller: controller)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('insight-topic-sugar')));
    await tester.pumpAndSettle();
    expect(
      controller.visible.every(
        (article) => article.topic == InsightTopic.sugar,
      ),
      isTrue,
    );
    expect(find.text('Sugar insights'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('insights-browse-all')));
    await tester.tap(find.byKey(const Key('insights-browse-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('insight-featured')), findsOneWidget);
    for (final article in InsightCatalogue.articles.skip(1)) {
      expect(find.byKey(Key('insight-card-${article.id}')), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'failed save tells the user and leaves bookmark state unchanged',
    (tester) async {
      final prefs = _MemoryPreferences()..failWrite = true;
      final controller = _controller(preferences: prefs);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(InsightsPage(controller: controller)));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(Key('insight-save-${controller.daily.first.id}')),
      );
      await tester.pumpAndSettle();
      expect(controller.saved, isEmpty);
      expect(find.textContaining('could not be saved'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('article sources launch their exact URL and keep copy recovery', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const launcher = MethodChannel('plugins.flutter.io/url_launcher');
    final launched = <MethodCall>[];
    var failByThrowing = false;
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(launcher, (
      call,
    ) async {
      launched.add(call);
      if (failByThrowing) {
        throw PlatformException(code: 'unavailable');
      }
      return false;
    });
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        launcher,
        null,
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    final controller = _controller();
    addTearDown(controller.dispose);
    final article = InsightCatalogue.byId('added-sugar')!;
    await tester.pumpWidget(
      _app(InsightArticlePage(article: article, controller: controller)),
    );
    await tester.pumpAndSettle();
    final open = find.widgetWithText(TextButton, 'Open source').first;
    await tester.ensureVisible(open);
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(launched.single.method, 'launch');
    expect(launched.single.arguments['url'], article.sources.first.url);
    expect(launched.single.arguments['useWebView'], isFalse);
    expect(launched.single.arguments['useSafariVC'], isFalse);
    expect(find.textContaining('Could not open the source.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    failByThrowing = true;
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(launched, hasLength(2));
    expect(find.textContaining('Could not open the source.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Copy link').first);
    await tester.pumpAndSettle();
    expect(copied, article.sources.first.url);
    expect(find.text('Source link copied'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'feed fits narrow through desktop and enlarged text $brightness',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final width in [320.0, 390.0, 768.0, 1024.0, 1440.0, 1728.0]) {
          for (final scale in [1.0, 2.0]) {
            tester.view.physicalSize = Size(width, 1200);
            final controller = _controller();
            await tester.pumpWidget(
              _app(
                InsightsPage(controller: controller),
                brightness: brightness,
                scale: scale,
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$width scale $scale $brightness',
            );
            await tester.pumpWidget(const SizedBox.shrink());
            controller.dispose();
          }
        }
      },
    );
  }
}
