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
