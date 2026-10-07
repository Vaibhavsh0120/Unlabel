import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/app/unlabel_theme.dart';
import 'package:unlabel/core/network/unlabel_repository.dart';
import 'package:unlabel/core/capture/live_camera.dart';
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
  @override
  Future<SearchPage> search(String query, {String? cursor}) async {
    queries.add(query);
    return loader == null ? _page(query) : loader!(query);
  }

  @override
  Future<ProductReport> loadReport(String barcode) async {
    reports++;
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
}) => MaterialApp(
  theme: UnlabelTheme.forBrightness(Brightness.light),
  home: ProductSearchPage(
    repository: repository,
    onOpenReport: onOpen ?? (_) async {},
    onEnterLabel: () {},
  ),
);

void main() {
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
      expect(find.text('Find a product'), findsOneWidget);
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
    'scan choices retain working manual and barcode actions at narrow enlarged text',
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
      var labels = 0, barcodes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScanLandingPage(
              camera: _UnavailableCamera(),
              pickPhoto: () async => null,
              onBarcode: () async {
                barcodes++;
              },
              onEnterLabel: () async {
                labels++;
              },
              onSearch: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('scan-primary')));
      await tester.tap(find.byKey(const Key('scan-primary')));
      await tester.pumpAndSettle();
      expect(labels, 1);
      await tester.ensureVisible(find.byKey(const Key('scan-mode-2')));
      await tester.tap(find.byKey(const Key('scan-mode-2')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('scan-primary')));
      await tester.tap(find.byKey(const Key('scan-primary')));
      await tester.pumpAndSettle();
      expect(barcodes, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
