import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/app/unlabel_theme.dart';
import 'package:unlabel/core/network/unlabel_repository.dart';
import 'package:unlabel/core/capture/live_camera.dart';
import 'package:unlabel/core/capture/automatic_label_reader.dart';
import 'package:unlabel/core/widgets/search_skeleton.dart';
import 'package:unlabel/features/scanner/presentation/product_search_page.dart';
import 'package:unlabel/features/scanner/presentation/scan_landing_page.dart';

class _UnavailableCamera extends LiveCamera {
  @override
  Future<void> start() async {}
}

class _Repository extends UnlabelRepository {
  _Repository() : super(baseUrl: 'https://example.test');
  final queries = <String>[];
  Future<SearchPage> Function(String)? loader;
  int reports = 0;
  Future<ProductReport> Function(String)? reportLoader;
  @override
  Future<SearchPage> search(String query, {String? cursor}) async {
    queries.add(query);
    return loader == null ? _page(query) : loader!(query);
  }

  @override
  Future<ResearchSearchPage> searchResearch(
    String query, {
    String? cursor,
  }) async => ResearchSearchPage.empty();

  @override
  Future<ProductReport> loadReport(String barcode) async {
    reports++;
    if (reportLoader != null) return reportLoader!(barcode);
    return ProductReport.fromJson(
      jsonDecode(
        File('../contracts/examples/label-report-v1.historical.synthetic.json')
            .readAsStringSync(),
      ) as JsonMap,
    );
  }
}

SearchPage _page(String name) => SearchPage.fromJson({
  'schema_version': '1',
  'search_version': 'catalogue-search-v1',
  'status': 'ready',
  'normalized_query': name,
  'candidates': [
    {
      'identity': {
        'barcode': '0123456789012',
        'name': name,
        'brands': 'Synthetic brand',
        'quantity_text': '400 g',
      },
      'source_id': 'synthetic-source',
    },
  ],
  'next_cursor': null,
  'matched_count': 1,
  'ambiguous': false,
  'warnings': [],
});

Widget _search(
  _Repository repository, {
  Future<void> Function(ProductReport)? onOpen,
  bool active = true,
}) => MaterialApp(
  theme: UnlabelTheme.forBrightness(Brightness.light),
  home: ProductSearchPage(
    repository: repository,
    onOpenReport: onOpen ?? (_) async {},
    onEnterLabel: () {},
    active: active,
  ),
);

void main() {
  testWidgets('reopening resumes a query cancelled while pending', (
    tester,
  ) async {
    final repository = _Repository();
    addTearDown(repository.close);
    final old = Completer<SearchPage>();
    repository.loader = (_) => repository.queries.length == 1
        ? old.future
        : Future.value(_page('Fresh result'));
    await tester.pumpWidget(_search(repository));
    await tester.enterText(find.byType(TextField), 'oats');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(_search(repository, active: false));
    await tester.pumpWidget(_search(repository));
    await tester.pumpAndSettle();
    expect(repository.queries, ['oats', 'oats']);
    expect(find.text('Fresh result'), findsOneWidget);
    old.complete(_page('Obsolete result'));
    await tester.pumpAndSettle();
    expect(find.text('Obsolete result'), findsNothing);
  });

  testWidgets('changed queries do not reload retained result thumbnails', (
    tester,
  ) async {
    final repository = _Repository();
    addTearDown(repository.close);
    final next = Completer<SearchPage>();
    final photo = Completer<ProductReport>();
    repository.loader = (query) =>
        query == 'next' ? next.future : Future.value(_page(query));
    repository.reportLoader = (_) => photo.future;
    await tester.pumpWidget(_search(repository));
    await tester.enterText(find.byType(TextField), 'old');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(repository.reports, 1);
    await tester.enterText(find.byType(TextField), 'next');
    await tester.pump(const Duration(milliseconds: 300));
    expect(repository.reports, 1);
    photo.complete(
      ProductReport.fromJson(
        jsonDecode(
          File(
            '../contracts/examples/label-report-v1.historical.synthetic.json',
          ).readAsStringSync(),
        ) as JsonMap,
      ),
    );
    await tester.pump();
    expect(repository.reports, 1);
    next.complete(_page('next'));
    await tester.pumpAndSettle();
    expect(repository.reports, 2);
  });
  testWidgets('first results show skeletons and reduced motion stays still', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final repository = _Repository();
    addTearDown(repository.close);
    final response = Completer<SearchPage>();
    repository.loader = (_) => response.future;
    await tester.pumpWidget(_search(repository));
    await tester.enterText(find.byType(TextField), 'oats');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.bySemanticsLabel('Searching products'), findsOneWidget);
    final pulse =
        tester
                .widget<AnimatedBuilder>(
                  find.descendant(
                    of: find.byType(SearchSkeleton),
                    matching: find.byType(AnimatedBuilder),
                  ),
                )
                .animation
            as AnimationController;
    await tester.pump(const Duration(seconds: 2));
    expect(pulse.isAnimating, isFalse);
    expect(pulse.value, .5);
    response.complete(_page('oats'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Searching products'), findsNothing);
  });

  testWidgets('thumbnail work is bounded and queued work stops after closing', (
    tester,
  ) async {
    final repository = _Repository();
    addTearDown(repository.close);
    repository.loader = (_) async {
      final value = jsonDecode(
        File('../contracts/examples/catalogue-search-v1.synthetic.json')
            .readAsStringSync(),
      ) as JsonMap;
      final first = (value['candidates'] as List).first as JsonMap;
      value['candidates'] = List.generate(
        10,
        (i) => {
          ...first,
          'identity': {
            ...first['identity'] as JsonMap,
            'barcode': '01234567890${i.toString().padLeft(2, '0')}',
          },
        },
      );
      value['matched_count'] = 10;
      return SearchPage.fromJson(value);
    };
    final pending = <Completer<ProductReport>>[];
    repository.reportLoader = (_) {
      final value = Completer<ProductReport>();
      pending.add(value);
      return value.future;
    };
    await tester.pumpWidget(_search(repository));
    await tester.enterText(find.byType(TextField), 'oats');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(repository.reports, 2);
    await tester.pumpWidget(const SizedBox());
    final report = ProductReport.fromJson(
      jsonDecode(
        File('../contracts/examples/label-report-v1.historical.synthetic.json')
            .readAsStringSync(),
      ) as JsonMap,
    );
    for (final value in pending) {
      value.complete(report);
    }
    await tester.pump();
    expect(repository.reports, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'search debounces typing, clears and opens the entire result including its photo',
    (tester) async {
      final repository = _Repository();
      addTearDown(repository.close);
      var opened = 0;
      await tester.pumpWidget(
        _search(repository, onOpen: (_) async => opened++),
      );
      await tester.enterText(
        find.byKey(const Key('product-search-input')),
        'o',
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(repository.queries, isEmpty);
      await tester.enterText(
        find.byKey(const Key('product-search-input')),
        'oa',
      );
      await tester.pump(const Duration(milliseconds: 150));
      await tester.enterText(
        find.byKey(const Key('product-search-input')),
        'oats',
      );
      await tester.pump(const Duration(milliseconds: 279));
      expect(repository.queries, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(repository.queries, ['oats']);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Text && widget.data == 'oats',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('search-image-0123456789012')));
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(
        repository.reports,
        1,
      ); // Thumbnail and selection share one report.
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is Text && widget.data == 'oats',
        ),
      );
      await tester.pumpAndSettle();
      expect(opened, 2);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('Search products'), findsOneWidget);
      expect(find.text('oats'), findsNothing);
    },
  );

  testWidgets(
    'obsolete response cannot overwrite a newer query or survive clearing/disposal',
    (tester) async {
      final repository = _Repository();
      addTearDown(repository.close);
      final old = Completer<SearchPage>();
      repository.loader = (query) =>
          query == 'old' ? old.future : Future.value(_page(query));
      await tester.pumpWidget(_search(repository));
      await tester.enterText(find.byType(TextField), 'old');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(find.byType(TextField), 'new');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      old.complete(_page('Obsolete result'));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Text && widget.data == 'new',
        ),
        findsOneWidget,
      );
      expect(find.text('Obsolete result'), findsNothing);
      await tester.enterText(find.byType(TextField), 'pending');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(repository.queries, ['old', 'new']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'header search hides branding/profile and Escape returns to the app',
    (tester) async {
      final repository = _Repository();
      addTearDown(repository.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: const Text('Unlabel'),
                actions: [
                  IconButton(
                    tooltip: 'Profile',
                    onPressed: () {},
                    icon: const Icon(Icons.person),
                  ),
                ],
              ),
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ProductSearchPage(
                      repository: repository,
                      onOpenReport: (_) async {},
                      onEnterLabel: () {},
                    ),
                  ),
                ),
                child: const Text('Search products'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Search products'));
      await tester.pumpAndSettle();
      expect(find.text('Unlabel'), findsNothing);
      expect(find.byTooltip('Profile'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Unlabel'), findsOneWidget);
    },
  );

  testWidgets(
    'scan gallery and barcode-photo actions work at narrow enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      var photos = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScanLandingPage(
              camera: _UnavailableCamera(),
              pickPhoto: () async {
                photos++;
                return null;
              },
              reader: AutomaticLabelReader(_Repository()),
              onResult: (_, _) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('scan-gallery')));
      await tester.tap(find.byKey(const Key('scan-gallery')));
      await tester.pumpAndSettle();
      expect(photos, 1);
      await tester.ensureVisible(find.byKey(const Key('scan-mode-0')));
      await tester.tap(find.byKey(const Key('scan-mode-0')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('scan-gallery')));
      await tester.tap(find.byKey(const Key('scan-gallery')));
      await tester.pumpAndSettle();
      expect(photos, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
