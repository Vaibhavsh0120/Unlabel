import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unlabel/app/unlabel_theme.dart';
import 'package:unlabel/core/network/unlabel_repository.dart';
import 'package:unlabel/features/scanner/presentation/product_search_page.dart';
import 'package:unlabel/features/scanner/presentation/product_info_page.dart';

String _id(String letter) => List.filled(64, letter).join();
JsonMap _source({String provider = 'retailer'}) => {
  'provider': provider,
  'url': 'https://example.test/india/product',
  'retrieved_at': '2026-10-08T04:00:00Z',
  'source_updated_at': null,
  'license': {
    'database': null,
    'contents': null,
    'images': null,
    'note': null,
    'reuse_status': 'factual_observations_only',
  },
};
JsonMap _identity(String name) => {
  'barcode': null,
  'name': name,
  'brand': 'Synthetic',
  'variant': 'Original',
  'quantity': '125 g',
  'market': 'india',
  'match': 'identity_unconfirmed',
  'barcode_evidence_url': null,
};
JsonMap _candidate(String id, String name) => {
  'entry_id': id,
  'identity': _identity(name),
  'provider': 'retailer',
  'source': _source(),
  'eligibility': 'identity_unconfirmed',
};
JsonMap _researchJson(
  String name, {
  String? id,
  String? cursor,
  bool empty = false,
}) => {
  'schema_version': '1',
  'search_version': 'research-search-v1',
  'status': empty ? 'not_found' : 'ready',
  'candidates': empty ? [] : [_candidate(id ?? _id('a'), name)],
  'matched_count': empty ? 0 : 3,
  'next_cursor': cursor,
};
JsonMap _detail({String? id, String name = 'Synthetic chocolate'}) {
  final entry = id ?? _id('a');
  return {
    'schema_version': '1',
    'status': 'found',
    'entry_id': entry,
    'conflict_fields': ['nutrition.sugars'],
    'warnings': [
      'researched_web_facts_not_current_package_confirmation',
      'allergen_safety_not_assessed',
    ],
    'observation': {
      'schema_version': 'popular-india-research-v1',
      'observation_id': entry,
      'source': _source(),
      'identity': _identity(name),
      'eligibility': 'identity_unconfirmed',
      'sections': {
        'ingredients': {
          'text': 'Wheat flour; sugar; milk solids.',
          'completeness': 'partial',
          'source_url': _source()['url'],
          'provenance': _source(),
        },
        'contains': null,
        'may_contain': null,
      },
      'nutrition': {
        'availability': 'direct_reported',
        'legacy_present': false,
        'legacy_aggregates': null,
        'direct_tables': [
          {
            'source': 'retailer_transcription',
            'basis': {'amount': 100, 'unit': 'g'},
            'preparation': 'as_sold',
            'source_url': _source()['url'],
            'retrieved_at': _source()['retrieved_at'],
            'source_updated_at': null,
            'provenance': _source(),
            'rows': [
              {
                'nutrient': 'sugars',
                'value': 9.5,
                'unit': 'g',
                'qualifier': 'less_than',
                'raw_label': 'Total sugars',
              },
              {
                'nutrient': 'sodium',
                'value': null,
                'unit': 'mg',
                'qualifier': 'unknown',
                'raw_label': 'Sodium',
              },
            ],
          },
        ],
      },
      'metadata': {
        'unknowns': ['Barcode unavailable; physical packet not inspected.'],
        'conflicts': [
          {
            'field': 'candidate_numeric_table.sugars',
            'alternatives': [
              {'value': 9.5, 'unit': 'g'},
              {'value': 12, 'unit': 'g'},
            ],
            'resolution': 'Keep both values without averaging.',
          },
        ],
        'candidate_numeric_table': {
          'source': 'retailer_attributes',
          'basis': {'amount': 100, 'unit': 'g'},
          'preparation': 'as_sold',
          'source_url': _source()['url'],
          'retrieved_at': _source()['retrieved_at'],
          'rows': [
            {
              'nutrient': 'sugars',
              'value': 9.5,
              'unit': 'g',
              'raw_label': 'Total sugars',
            },
          ],
        },
        'candidate_numeric_table_alternatives': [
          {
            'source': 'retailer_summary',
            'basis': {},
            'preparation': 'unknown',
            'rows': [
              {
                'nutrient': 'sugars',
                'value': 12,
                'unit': 'g',
                'raw_label': 'Total sugars',
              },
            ],
          },
        ],
      },
    },
  };
}

JsonMap _offJson(
  String name, {
  String code = '0123456789012',
  String? cursor,
  bool empty = false,
}) => {
  'schema_version': '1',
  'search_version': 'catalogue-search-v1',
  'status': empty ? 'not_found' : 'ready',
  'normalized_query': name,
  'candidates': empty
      ? []
      : [
          {
            'identity': {
              'barcode': code,
              'name': name,
              'brands': 'Synthetic',
              'quantity_text': '400 g',
            },
            'source_id': 'synthetic-source',
          },
        ],
  'next_cursor': cursor,
  'matched_count': empty ? 0 : 3,
  'ambiguous': false,
  'warnings': [],
};
JsonMap _metadata({bool research = true, bool labels = true}) => {
  'api_major': 1,
  'contract_schema': '1',
  'report_version': 'label-report-v1',
  'capabilities': {
    'label_reports': labels,
    'catalogue_search': true,
    if (research) 'research_catalogue': true,
  },
};

class _Repository extends UnlabelRepository {
  _Repository() : super(baseUrl: 'https://example.test');
  Future<SearchPage> Function(String, String?)? off;
  Future<ResearchSearchPage> Function(String, String?)? research;
  final offCursors = <String?>[], researchCursors = <String?>[];
  @override
  Future<SearchPage> search(String query, {String? cursor}) async {
    offCursors.add(cursor);
    return off == null
        ? SearchPage.fromJson(_offJson(query, empty: true))
        : off!(query, cursor);
  }

  @override
  Future<ResearchSearchPage> searchResearch(
    String query, {
    String? cursor,
  }) async {
    researchCursors.add(cursor);
    return research == null
        ? ResearchSearchPage.empty()
        : research!(query, cursor);
  }

  @override
  Future<ResearchedProduct> loadResearchProduct(String entryId) async =>
      ResearchedProduct.fromJson(_detail(id: entryId));
  @override
  Future<ProductReport> loadReport(String barcode) async =>
      ProductReport.fromJson(
        jsonDecode(
          File(
            '../contracts/examples/label-report-v1.historical.synthetic.json',
          ).readAsStringSync(),
        ) as JsonMap,
      );
}

Widget _search(_Repository repository) => MaterialApp(
  theme: UnlabelTheme.forBrightness(Brightness.light),
  home: ProductSearchPage(
    repository: repository,
    autofocus: false,
    onOpenReport: (_) async {},
    onEnterLabel: () {},
  ),
);
Future<void> _query(WidgetTester tester, String value) async {
  await tester.enterText(find.byKey(const Key('product-search-input')), value);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

void main() {
  test('product images retain source scope and reject private or incompatible descriptors', () {
    JsonMap imageDetail() {
      final value = _detail();
      final record = value['observation'] as JsonMap;
      const sourceUrl = 'https://blinkit.com/prn/synthetic/prid/123';
      record['source']['url'] = sourceUrl;
      record['sections']['ingredients']['source_url'] = sourceUrl;
      record['sections']['ingredients']['provenance']['url'] = sourceUrl;
      for (final table in record['nutrition']['direct_tables']) {
        table['source_url'] = sourceUrl;
        table['provenance']['url'] = sourceUrl;
      }
      value['image'] = {
        'observation_id': value['entry_id'],
        'source_url': sourceUrl,
        'provider': 'retailer',
        'url': 'https://cdn.grofers.com/product.jpg',
        'identity_scope': 'source_listing',
        'content_type': 'image/jpeg',
        'method': 'structured_product',
        'evidence_sha256': _id('b'),
        'retrieved_at': '2026-10-08T04:00:00Z',
        'attribution': 'Retailer product listing',
        'license': 'URL descriptor only',
      };
      return value;
    }

    expect(
      ResearchedProduct.fromJson(imageDetail()).imageUrl,
      'https://cdn.grofers.com/product.jpg',
    );
    for (final change in <JsonMap>[
      {'url': 'https://localhost/product.jpg'},
      {'url': 'https://cdn.grofers.com/product.jpg?api_key=private'},
      {'identity_scope': 'source_barcode'},
      {'method': 'off_selected_front'},
      {'content_type': 'image/svg+xml'},
      {'observation_id': _id('c')},
    ]) {
      final value = imageDetail();
      (value['image'] as JsonMap).addAll(change);
      expect(
        () => ResearchedProduct.fromJson(value),
        throwsA(isA<AppFailure>()),
      );
    }
  });
  testWidgets('research declarations remain readable by assistive technology', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1440, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: UnlabelTheme.forBrightness(Brightness.light),
        home: ProductInfoPage.research(
          product: ResearchedProduct.fromJson(_detail()),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Wheat flour; sugar; milk solids.'));
    await tester.pump();
    expect(
      find.bySemanticsLabel('Wheat flour; sugar; milk solids.'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('https://example.test/india/product'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  test(
    'the current shared research corpus is readable without losing facts',
    () {
      final source = File(
        '../data/catalogue/popular-india-v1/observations.jsonl.gz',
      );
      final records = const LineSplitter()
          .convert(utf8.decode(gzip.decode(source.readAsBytesSync())))
          .where((line) => line.isNotEmpty)
          .map((line) => jsonDecode(line) as JsonMap)
          .toList();
      expect(records, isNotEmpty);
      final providers = <String>{};
      for (final record in records) {
        final product = ResearchedProduct.fromJson({
          'schema_version': '1',
          'status': 'found',
          'entry_id': record['observation_id'],
          'observation': record,
          'conflict_fields': [],
          'warnings': [],
        });
        expect(product.raw, equals(record), reason: product.entryId);
        providers.add(product.provider);
      }
      expect(
        providers,
        containsAll(['manufacturer', 'retailer', 'open_food_facts']),
      );
    },
  );

  test('null barcode, dated provenance, qualifiers and alternatives survive immutable parsing', () {
    final input = _detail();
    final product = ResearchedProduct.fromJson(input);
    expect(product.barcode, isNull);
    expect(product.sourceUpdatedAt, isNull);
    expect(product.retrievedAt, '2026-10-08T04:00:00Z');
    expect(product.tables.first['rows'][0]['qualifier'], 'less_than');
    expect(product.tables.first['rows'][1]['value'], isNull);
    (input['observation']['metadata']['unknowns'] as List).clear();
    expect(product.metadata['unknowns'], isNotEmpty);
    expect(
      () => product.raw['identity']['barcode'] = '00000000',
      throwsUnsupportedError,
    );
    expect(
      () => (product.metadata['conflicts'] as List).clear(),
      throwsUnsupportedError,
    );
    expect(() => product.tables.clear(), throwsUnsupportedError);
  });

  test('rejects malformed identities, dates, nutrition and metadata before display', () {
    final mutations = <void Function(JsonMap)>[
      (v) => v['observation']['identity']['barcode'] = 'not-a-barcode',
      (v) => v['observation']['identity']['match'] = 'exact_sku',
      (v) => v['observation']['source']['retrieved_at'] = '20261008',
      (v) => v['observation']['source']['retrieved_at'] = '2026-10-08T04:00:00',
      (v) =>
          v['observation']['source']['retrieved_at'] = '2026-02-31T04:00:00Z',
      (v) => v['observation']['source']['source_updated_at'] =
          '2026-10-09T04:00:00Z',
      (v) => v['observation']['source']['url'] =
          'https://example.test/?token=private',
      (v) =>
          v['observation']['nutrition']['direct_tables'][0]['rows'][0]['qualifier'] =
              'safe',
      (v) =>
          v['observation']['nutrition']['direct_tables'][0]['rows'][1]['qualifier'] =
              'exact',
      (v) =>
          v['observation']['nutrition']['direct_tables'][0]['basis']['amount'] =
              -1,
      (v) => v['observation']['nutrition']['direct_tables'][0]['source'] =
          'manufacturer',
      (v) => v['observation']['metadata']['unknowns'] = List.filled(
        201,
        'Unknown',
      ),
    ];
    for (final mutate in mutations) {
      final input = _detail();
      mutate(input);
      expect(
        () => ResearchedProduct.fromJson(input),
        throwsA(isA<AppFailure>()),
      );
    }
    final duplicate = _researchJson('Duplicate');
    duplicate['candidates'].add(duplicate['candidates'].first);
    expect(
      () => ResearchSearchPage.fromJson(duplicate),
      throwsA(isA<AppFailure>()),
    );
  });

  test('older service research capability is optional and does not trigger a request', () async {
    var requests = 0;
    final repository = UnlabelRepository(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        requests++;
        expect(request.url.path, '/v1/meta');
        return http.Response(jsonEncode(_metadata(research: false)), 200);
      }),
    );
    addTearDown(repository.close);
    expect(
      (await repository.searchResearch('chocolate')).status,
      'unavailable',
    );
    expect(requests, 1);
  });

  test('research search is independent of label reports and failed details are not cached', () async {
    var details = 0;
    final repository = UnlabelRepository(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        expect(request.headers.containsKey('authorization'), isFalse);
        if (request.url.path == '/v1/meta') {
          return http.Response(jsonEncode(_metadata(labels: false)), 200);
        }
        if (request.url.path.endsWith('/search')) {
          return http.Response(jsonEncode(_researchJson('Chocolate')), 200);
        }
        details++;
        if (details == 1) return http.Response('{}', 404);
        return http.Response(jsonEncode(_detail()), 200);
      }),
    );
    addTearDown(repository.close);
    expect(
      (await repository.searchResearch('chocolate')).candidates.single.barcode,
      isNull,
    );
    await expectLater(
      repository.loadResearchProduct(_id('a')),
      throwsA(
        isA<AppFailure>().having(
          (e) => e.userMessage,
          'message',
          contains('product source'),
        ),
      ),
    );
    expect((await repository.loadResearchProduct(_id('a'))).barcode, isNull);
    await repository.loadResearchProduct(_id('a'));
    expect(details, 2);
  });

  testWidgets(
    'real backend warnings remain understandable and unknown identifiers stay hidden',
    (tester) async {
      final response = _detail();
      (response['warnings'] as List).addAll(<String>[
        'new_internal_source_warning',
        'another_private_implementation_identifier',
      ]);
      await tester.pumpWidget(
        MaterialApp(
          theme: UnlabelTheme.forBrightness(Brightness.light),
          home: ProductInfoPage.research(
            product: ResearchedProduct.fromJson(response),
          ),
        ),
      );
      expect(
        find.text('Website facts do not confirm your current package.'),
        findsOneWidget,
      );
      expect(
        find.text('Allergen safety has not been assessed.'),
        findsOneWidget,
      );
      expect(
        find.text('Some source information is unavailable.'),
        findsOneWidget,
      );
      for (final identifier in response['warnings'] as List) {
        expect(find.text(identifier as String), findsNothing);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'research rows expose imported variants and avoid repeating the product name',
    (tester) async {
      final repository = _Repository();
      addTearDown(repository.close);
      final response = _researchJson(
        'Twix Cookie Caramel Chocolate Filled Bar',
      );
      response['candidates'][0]['identity']['variant'] =
          'Cookie Caramel (imported Netherlands offer)';
      final repeated = _candidate(_id('b'), 'Synthetic Original');
      repeated['identity']['variant'] = 'Original';
      (response['candidates'] as List).add(repeated);
      repository.research = (_, _) async =>
          ResearchSearchPage.fromJson(response);
      await tester.pumpWidget(_search(repository));
      await _query(tester, 'chocolate');
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Cookie Caramel (imported Netherlands offer)'),
        findsOneWidget,
      );
      final repeatedTile = tester.widget<ListTile>(
        find.byKey(ValueKey('research-${_id('b')}')),
      );
      expect(
        (repeatedTile.subtitle! as Text).data,
        isNot(contains('Original')),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fast research rows are readable before another source finishes or fails',
    (tester) async {
      final repository = _Repository();
      addTearDown(repository.close);
      final pending = Completer<SearchPage>();
      repository.off = (_, _) => pending.future;
      repository.research = (_, _) async =>
          ResearchSearchPage.fromJson(_researchJson('Fast chocolate'));
      await tester.pumpWidget(_search(repository));
      await _query(tester, 'chocolate');
      expect(find.text('Fast chocolate'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      pending.completeError(
        const AppFailure('unavailable', 'Catalogue source unavailable.'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fast chocolate'), findsOneWidget);
      expect(find.text('Some sources could not be loaded'), findsOneWidget);
      await tester.tap(find.text('Fast chocolate'));
      await tester.pumpAndSettle();
      expect(find.text('Product info'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mixed pagination retries failed source cursor without losing successful pages',
    (tester) async {
      final repository = _Repository();
      addTearDown(repository.close);
      var offCalls = 0;
      repository.off = (_, cursor) async {
        offCalls++;
        if (offCalls == 2) {
          throw const FormatException('Broken source response');
        }
        return SearchPage.fromJson(
          _offJson(
            offCalls == 1 ? 'OFF first' : 'OFF second',
            code: offCalls == 1 ? '0123456789012' : '0123456789013',
            cursor: offCalls == 1 ? 'off-next' : null,
          ),
        );
      };
      repository.research = (_, cursor) async => ResearchSearchPage.fromJson(
        _researchJson(
          cursor == null
              ? 'Research first'
              : cursor == 'research-next'
              ? 'Research second'
              : 'Research third',
          id: cursor == null
              ? _id('a')
              : cursor == 'research-next'
              ? _id('b')
              : _id('c'),
          cursor: cursor == null
              ? 'research-next'
              : cursor == 'research-next'
              ? 'research-last'
              : null,
        ),
      );
      await tester.pumpWidget(_search(repository));
      await _query(tester, 'chocolate');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Show more products'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Show more products'));
      await tester.pumpAndSettle();
      expect(find.text('Research second'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Show more products'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Show more products'));
      await tester.pumpAndSettle();
      expect(repository.offCursors, [null, 'off-next', 'off-next']);
      expect(repository.researchCursors, [
        null,
        'research-next',
        'research-last',
      ]);
      await tester.scrollUntilVisible(
        find.text('OFF second'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('OFF second'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'obsolete research response and unavailable fallback cannot mask new results',
    (tester) async {
      final repository = _Repository();
      addTearDown(repository.close);
      final old = Completer<ResearchSearchPage>();
      repository.research = (q, _) =>
          q == 'old' ? old.future : Future.value(ResearchSearchPage.empty());
      await tester.pumpWidget(_search(repository));
      await _query(tester, 'old');
      await _query(tester, 'new');
      await tester.pumpAndSettle();
      old.complete(ResearchSearchPage.fromJson(_researchJson('Obsolete')));
      await tester.pumpAndSettle();
      expect(find.text('Obsolete'), findsNothing);
      expect(find.text('No matches for “new”'), findsOneWidget);
      expect(find.text('Catalogue search is unavailable'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 1440.0]) {
    testWidgets(
      'source details preserve alternatives and unknown basis at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = width == 320
            ? 2
            : 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          MaterialApp(
            theme: UnlabelTheme.forBrightness(Brightness.light),
            home: ProductInfoPage.research(
              product: ResearchedProduct.fromJson(_detail()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Partial declaration'), findsOneWidget);
        expect(find.text('Less than 9.5 g'), findsOneWidget);
        expect(find.text('Not declared in this source'), findsNWidgets(2));
        await tester.ensureVisible(
          find.text('Source notes and missing information'),
        );
        await tester.tap(find.text('Source notes and missing information'));
        await tester.pumpAndSettle();
        expect(find.text('Alternative website values'), findsOneWidget);
        expect(find.text('Basis unknown'), findsOneWidget);
        expect(find.text('12 g'), findsOneWidget);
        expect(find.text('Barcode unknown'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
