import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unlabel/core/network/scanner_auth.dart';
import 'package:unlabel/core/network/unlabel_repository.dart';
import 'package:unlabel/core/storage/local_store.dart';

JsonMap fixture(String name) =>
    jsonDecode(File('../contracts/examples/$name').readAsStringSync())
        as JsonMap;
JsonMap current() => fixture('label-report-v1.current.synthetic.json');
JsonMap historical() => fixture('label-report-v1.historical.synthetic.json');

JsonMap get metadata => {
  'api_major': 1,
  'contract_schema': '1',
  'report_version': 'label-report-v1',
  'capabilities': {
    'label_reports': true,
    'catalogue_search': true,
    'community_contributions': true,
  },
};

LabelDraft draft({
  List<DraftNutrient> rows = const [],
  DraftBasis basis = const DraftBasis(),
  bool confirmed = true,
}) => LabelDraft(
  name: 'Synthetic oats',
  ingredients: const DraftSection(
    status: 'present',
    text: 'Oats, milk',
    complete: true,
  ),
  rows: rows,
  basis: basis,
  frontConfirmed: confirmed,
  backConfirmed: confirmed,
  samePackageConfirmed: confirmed,
  observedAt: DateTime.utc(2026, 10, 7),
);

Matcher failure(String kind) =>
    isA<AppFailure>().having((value) => value.kind, 'kind', kind);

class MemoryPreferences implements PreferencesAdapter {
  final values = <String, String>{};
  bool failWrites = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('Synthetic disk full');
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async => values.remove(key);
}

class ThrowingAuth implements ScannerAuth {
  int calls = 0;
  @override
  Future<String?> token() async {
    calls++;
    throw StateError('Synthetic identity unavailable');
  }
}

class StreamingClient extends http.BaseClient {
  StreamingClient(this.handler);
  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}

void main() {
  group('real exported report contracts', () {
    test(
      'current report preserves original sugar basis and unknown nutrients',
      () {
        final report = ProductReport.fromJson(current());
        expect(report.isHistorical, isFalse);
        expect(report.sugar!.grams, 12);
        expect(report.sugar!.cubes, 3);
        expect(report.sugar!.basisLabel, contains('40 g'));
        expect(
          report.nutrients.firstWhere((value) => value.name == 'protein').value,
          isNull,
        );
        expect(
          report.nutrients.firstWhere((value) => value.name == 'sugars').value,
          30,
        );
        expect(report.nutrients.first.sourceIds, ['confirmed-label']);
        expect(report.mayContain.status, 'not_captured');
        expect(report.ingredientInsights, hasLength(1));
        expect(report.claims.single.status, 'contradicted');
        expect(() => report.raw['status'] = 'ready', throwsUnsupportedError);
        expect(
          () => (report.raw['identity'] as JsonMap)['name'] = 'Changed',
          throwsUnsupportedError,
        );
      },
    );
    test('historical conflicting nutrients stay unknown and source references survive', () {
      final report = ProductReport.fromJson(historical());
      expect(report.isHistorical, isTrue);
      expect(report.barcode, '0123456789012');
      expect(
        report.nutrients.singleWhere((value) => value.name == 'protein').value,
        isNull,
      );
      expect(
        report.nutrients.singleWhere((value) => value.name == 'protein').state,
        'conflict',
      );
      expect(
        report.nutrients
            .singleWhere((value) => value.name == 'protein')
            .sourceIds,
        hasLength(2),
      );
      expect(report.sourceLabels.join(' '), contains('ODbL'));
      expect(report.sourceLabels.join(' '), contains('unreviewed'));
      expect(report.sugar, isNull);
    });
    test('printed zero survives and malformed nested values fail safely', () {
      final value = current();
      (value['nutrition']['tables'][0]['nutrients']['sugars']
              as JsonMap)['value'] =
          0.0;
      expect(
        ProductReport.fromJson(value).nutrients
            .singleWhere((entry) => entry.name == 'sugars')
            .value,
        0,
      );
      value['ingredients']['text'] = 0;
      expect(
        () => ProductReport.fromJson(value),
        throwsA(failure('invalid_response')),
      );
      final malformed = current();
      malformed['nutrition']['tables'][0]['nutrients']['protein']['value'] =
          '0';
      expect(
        () => ProductReport.fromJson(malformed),
        throwsA(failure('invalid_response')),
      );
    });
    test(
      'conflicting historical identity does not silently choose an OFF product',
      () {
        final value = historical();
        final fields = value['resolved']['fields'] as List;
        fields.removeWhere((dynamic item) => item['field'] == 'identity.name');
        fields.add({
          'field': 'identity.name',
          'state': 'conflict',
          'value': null,
        });
        expect(ProductReport.fromJson(value).name, 'Product name unavailable');
      },
    );
    test('nullable brand-only search record is valid, unsupported barcode lengths are not', () {
      final item = {
        'identity': {
          'barcode': '0123456789012',
          'name': null,
          'brands': 'Synthetic brand',
          'quantity_text': null,
        },
        'source_id': 'off:synthetic:0123456789012',
      };
      expect(SearchCandidate.fromJson(item).name, 'Product name unavailable');
      (item['identity'] as JsonMap)['barcode'] = '123456789';
      expect(
        () => SearchCandidate.fromJson(item),
        throwsA(failure('invalid_response')),
      );
    });
  });

  test('actual exported discovery contract parses and malformed nested response is refused', () {
    final page = SearchPage.fromJson(
      fixture('catalogue-search-v1.synthetic.json'),
    );
    expect(page.status, 'ready');
    expect(page.candidates.single.barcode, '0123456789012');
    expect(page.candidates.single.imageUrl, isNull);
    final unreadable = fixture('catalogue-search-v1.synthetic.json');
    unreadable['candidates'] = {};
    expect(
      () => SearchPage.fromJson(unreadable),
      throwsA(failure('invalid_response')),
    );
    final saved = current();
    saved['storage']['status'] = 'saved';
    expect(
      () => ProductReport.fromJson(saved),
      throwsA(failure('invalid_response')),
    );
  });

  test('disabled community saves skip identity setup while label analysis remains available', () async {
    final auth = ThrowingAuth();
    final repository = UnlabelRepository(
      baseUrl: 'https://example.test',
      auth: auth,
      client: MockClient((request) async {
        if (request.url.path == '/v1/meta') {
          return http.Response(
            jsonEncode({
              ...metadata,
              'capabilities': {
                'label_reports': true,
                'community_contributions': false,
              },
            }),
            200,
          );
        }
        return http.Response.bytes(utf8.encode(jsonEncode(current())), 200);
      }),
    );
    expect(await repository.checkLabel(draft()), isA<ProductReport>());
    expect(auth.calls, 0);
    repository.close();
  });

  test(
    'a hanging identity provider is bounded and does not prevent analysis',
    () async {
      final pending = Completer<String?>();
      final auth = SingleFlightScannerAuth(
        resolve: () => pending.future,
        timeout: const Duration(milliseconds: 10),
      );
      final repository = UnlabelRepository(
        baseUrl: 'https://example.test',
        auth: auth,
        authTimeout: const Duration(milliseconds: 2),
        client: MockClient((request) async {
          if (request.url.path == '/v1/meta') {
            return http.Response(jsonEncode(metadata), 200);
          }
          return http.Response.bytes(utf8.encode(jsonEncode(current())), 200);
        }),
      );
      expect(await repository.checkLabel(draft()), isA<ProductReport>());
      pending.complete(null);
      repository.close();
    },
  );

  test('appearance persists independently and list clears preserve unrelated preferences', () async {
    final preferences = MemoryPreferences();
    final store = LocalStore(preferences: preferences);
    expect(await store.appearance(), 'light');
    await store.setAppearance('dark');
    expect(await LocalStore(preferences: preferences).appearance(), 'dark');
    await store.clearHistory();
    await store.clearSaved();
    expect(await store.appearance(), 'dark');
    await expectLater(
      store.setAppearance('invalid'),
      throwsA(failure('invalid_input')),
    );
    preferences.failWrites = true;
    await expectLater(
      store.setAppearance('light'),
      throwsA(failure('local_storage')),
    );
    expect(await store.appearance(), 'dark');
  });

  test(
    'large report stays readable but cannot exceed local report byte budget',
    () async {
      final value = historical();
      final fields = value['resolved_nutrients'] as List;
      final protein = fields.singleWhere(
        (dynamic item) => item['field'].endsWith('.protein'),
      ) as JsonMap;
      final alternative = (protein['alternatives'] as List).first;
      protein['alternatives'] = List.generate(144, (_) => alternative);
      value['resolved_nutrients'] = List.generate(8, (_) => protein);
      final report = ProductReport.fromJson(value);
      final preferences = MemoryPreferences();
      final store = LocalStore(preferences: preferences);
      await expectLater(
        store.record(report),
        throwsA(failure('local_capacity')),
      );
      expect(preferences.values, isEmpty);
      expect(report.nutrients, hasLength(8));
    },
  );

  group('independent corrected package draft', () {
    test('no automatic confirmation and no provider copies', () {
      expect(
        () => draft(confirmed: false).toPayload(),
        throwsA(failure('invalid_input')),
      );
      final payload = draft().toPayload();
      expect(payload['observation']['provider_references'], isEmpty);
      expect(payload['observation']['capture_method'], 'manual');
      expect(payload['observation']['share_license'], 'CC0-1.0');
      expect(
        payload['observation']['ingredients']['origin'],
        'independently_transcribed_package',
      );
      expect(payload['context']['food_category'], 'unknown');
    });
    test('empty nutrient is unknown and explicit zero stays zero', () {
      final payload = draft(
        rows: const [
          DraftNutrient(name: 'protein', unit: 'g'),
          DraftNutrient(name: 'sugars', value: 0, unit: 'g'),
        ],
        basis: const DraftBasis(kind: 'serving'),
      ).toPayload();
      expect(payload['observation']['rows'][0]['value'], isNull);
      expect(payload['observation']['rows'][1]['value'], 0.0);
      expect(payload['observation']['rows'][0]['basis'], {
        'kind': 'serving',
        'amount': null,
        'unit': null,
      });
    });
    test(
      'quantity basis must be explicit and row units match nutrient type',
      () {
        expect(
          () => draft(
            rows: const [DraftNutrient(name: 'protein', value: 2, unit: 'g')],
          ).toPayload(),
          throwsA(failure('invalid_input')),
        );
        expect(
          () => draft(
            rows: const [
              DraftNutrient(name: 'protein', value: 2, unit: 'kcal'),
            ],
            basis: const DraftBasis(amount: 100, unit: 'g'),
          ).toPayload(),
          throwsA(failure('invalid_input')),
        );
      },
    );
    test(
      'unchanged draft keeps its UUID and new edited draft gets a new one',
      () {
        final first = draft();
        expect(
          first.toPayload()['observation']['submission_id'],
          first.toPayload()['observation']['submission_id'],
        );
        expect(
          first.submissionId,
          matches(
            RegExp(
              r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
            ),
          ),
        );
        expect(draft().submissionId, isNot(first.submissionId));
      },
    );
  });

  group('bounded network and capabilities', () {
    test(
      'coalesces metadata, preserves cursor and reads without authentication',
      () async {
        final requests = <http.Request>[];
        final auth = ThrowingAuth();
        final repository = UnlabelRepository(
          baseUrl: 'https://example.test',
          auth: auth,
          client: MockClient((request) async {
            requests.add(request);
            if (request.url.path == '/v1/meta') {
              return http.Response(jsonEncode(metadata), 200);
            }
            if (request.url.path.endsWith('/report')) {
              return http.Response(jsonEncode(historical()), 200);
            }
            return http.Response(
              jsonEncode({
                'schema_version': '1',
                'search_version': 'catalogue-search-v1',
                'status': 'not_found',
                'normalized_query': 'oats',
                'candidates': [],
                'next_cursor': null,
                'matched_count': 0,
                'ambiguous': false,
                'warnings': [],
              }),
              200,
            );
          }),
        );
        await Future.wait([
          repository.loadReport('0123456789012'),
          repository.search(' oats ', cursor: 'opaque-continuation'),
        ]);
        expect(
          requests.where((request) => request.url.path == '/v1/meta'),
          hasLength(1),
        );
        expect(requests.first.url.path, '/v1/meta');
        expect(
          requests.last.url.queryParameters['cursor'],
          'opaque-continuation',
        );
        expect(auth.calls, 0);
        expect(
          requests.every(
            (request) => !request.headers.containsKey('Authorization'),
          ),
          isTrue,
        );
        repository.close();
      },
    );
    test('incompatible metadata blocks report/auth and missing search only blocks search', () async {
      var reports = 0;
      final auth = ThrowingAuth();
      final repository = UnlabelRepository(
        baseUrl: 'https://example.test',
        auth: auth,
        client: MockClient((request) async {
          if (request.url.path == '/v1/meta') {
            return http.Response(
              jsonEncode({...metadata, 'api_major': 2}),
              200,
            );
          }
          reports++;
          return http.Response('{}', 200);
        }),
      );
      await expectLater(
        repository.checkLabel(draft()),
        throwsA(failure('incompatible_service')),
      );
      expect(auth.calls, 0);
      expect(reports, 0);
      repository.close();
      final legacy = UnlabelRepository(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          if (request.url.path == '/v1/meta') {
            return http.Response(
              jsonEncode({
                ...metadata,
                'capabilities': {'label_reports': true},
              }),
              200,
            );
          }
          return http.Response(jsonEncode(historical()), 200);
        }),
      );
      await expectLater(
        legacy.search('oats'),
        throwsA(failure('unsupported_feature')),
      );
      expect(await legacy.loadReport('0123456789012'), isA<ProductReport>());
      legacy.close();
    });
    test('auth failure still analyzes one request and exposes separate storage outcome', () async {
      final auth = ThrowingAuth();
      var writes = 0;
      final repository = UnlabelRepository(
        baseUrl: 'https://example.test',
        auth: auth,
        client: MockClient((request) async {
          if (request.url.path == '/v1/meta') {
            return http.Response(jsonEncode(metadata), 200);
          }
          writes++;
          expect(request.headers.containsKey('Authorization'), isFalse);
          final value = current();
          value['storage']['status'] = 'authentication_required';
          return http.Response.bytes(
            utf8.encode(jsonEncode(value)),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      expect(
        (await repository.checkLabel(draft())).storageStatus,
        'authentication_required',
      );
      expect(auth.calls, 1);
      expect(writes, 1);
      repository.close();
    });
    test(
      '401 is not replayed and raw provider errors never reach the UI',
      () async {
        var writes = 0;
        final repository = UnlabelRepository(
          baseUrl: 'https://example.test',
          client: MockClient((request) async {
            if (request.url.path == '/v1/meta') {
              return http.Response(jsonEncode(metadata), 200);
            }
            writes++;
            return http.Response(
              'synthetic-private-token/provider traceback',
              401,
            );
          }),
        );
        try {
          await repository.checkLabel(draft());
          fail('Expected failure');
        } on AppFailure catch (value) {
          expect(value.kind, 'authentication');
          expect(value.userMessage, isNot(contains('synthetic-private')));
        }
        expect(writes, 1);
        repository.close();
      },
    );
    test(
      'size guard cancels oversized streamed body before it is collected',
      () async {
        var cancelled = false;
        final stream = StreamController<List<int>>(
          onCancel: () => cancelled = true,
        );
        final repository = UnlabelRepository(
          baseUrl: 'https://example.test',
          maxResponseBytes: 1024,
          client: StreamingClient((request) async {
            if (request.url.path == '/v1/meta') {
              return http.StreamedResponse(
                Stream.value(utf8.encode(jsonEncode(metadata))),
                200,
              );
            }
            scheduleMicrotask(() {
              stream.add(List.filled(1025, 65));
            });
            return http.StreamedResponse(stream.stream, 200);
          }),
        );
        await expectLater(
          repository.loadReport('0123456789012'),
          throwsA(failure('response_too_large')),
        );
        expect(cancelled, isTrue);
        await stream.close();
        repository.close();
      },
    );
    test(
      'timeout aborts request and unsafe service URLs are rejected',
      () async {
        var aborted = false;
        final repository = UnlabelRepository(
          baseUrl: 'https://example.test',
          timeout: const Duration(milliseconds: 5),
          client: StreamingClient((request) async {
            (request as http.AbortableRequest).abortTrigger!.then(
              (_) => aborted = true,
            );
            return Completer<http.StreamedResponse>().future;
          }),
        );
        await expectLater(
          repository.loadReport('0123456789012'),
          throwsA(failure('timeout')),
        );
        await Future<void>.delayed(Duration.zero);
        expect(aborted, isTrue);
        repository.close();
        for (final url in [
          'http://example.test',
          'https://user:secret@example.test',
          'https://example.test/?token=x',
          'https://example.test/#x',
        ]) {
          expect(
            () => UnlabelRepository(baseUrl: url),
            throwsA(failure('configuration')),
          );
        }
        final local = UnlabelRepository(
          baseUrl: 'http://127.0.0.1:8000',
          allowLocalHttp: true,
        );
        local.close();
        expect(
          () => UnlabelRepository(
            baseUrl: 'http://127.0.0.1:8000',
            allowLocalHttp: false,
          ),
          throwsA(failure('configuration')),
        );
      },
    );
  });

  test(
    'anonymous operation remains coalesced even when a caller times out',
    () async {
      var calls = 0;
      final result = Completer<String?>();
      final auth = SingleFlightScannerAuth(
        resolve: () {
          calls++;
          return result.future;
        },
        timeout: const Duration(milliseconds: 5),
      );
      expect(await auth.token(), isNull);
      final later = auth.token();
      result.complete('synthetic-id-token');
      expect(await later, 'synthetic-id-token');
      expect(calls, 1);
    },
  );

  group('private bounded device history and saved products', () {
    ProductReport indexed(int index) {
      final value = current();
      value['identity']['name'] = 'Synthetic product $index';
      return ProductReport.fromJson(value);
    }

    test(
      'history evicts to100, saved caps50, same product deduplicates',
      () async {
        final preferences = MemoryPreferences();
        final store = LocalStore(preferences: preferences);
        for (var index = 0; index < 101; index++) {
          await store.record(indexed(index));
        }
        final history = await store.history();
        expect(history, hasLength(100));
        expect(history.first.report.name, 'Synthetic product 100');
        for (var index = 0; index < 50; index++) {
          await store.save(indexed(index));
        }
        await expectLater(
          store.save(indexed(50)),
          throwsA(failure('local_capacity')),
        );
        await store.save(indexed(0));
        expect(await store.saved(), hasLength(50));
        await store.removeSaved(indexed(0).id);
        expect(await store.saved(), hasLength(49));
        expect(
          preferences.values.values.join(),
          isNot(contains('synthetic-id-token')),
        );
      },
    );
    test('parallel writes preserve both records and failures leave saved list intact', () async {
      final preferences = MemoryPreferences();
      final store = LocalStore(preferences: preferences);
      await Future.wait([store.save(indexed(1)), store.save(indexed(2))]);
      expect(await store.saved(), hasLength(2));
      preferences.failWrites = true;
      await expectLater(
        store.save(indexed(3)),
        throwsA(failure('local_storage')),
      );
      expect(await store.saved(), hasLength(2));
    });
    test('bad entries recover explicitly; wholly corrupt lists reset only app namespace', () async {
      final preferences = MemoryPreferences();
      final store = LocalStore(preferences: preferences);
      await store.record(indexed(1));
      final data =
          jsonDecode(preferences.values[LocalStore.historyKey]!) as JsonMap;
      (data['entries'] as List).add({'bad': 'synthetic malformed'});
      preferences.values[LocalStore.historyKey] = jsonEncode(data);
      expect(await store.history(), hasLength(1));
      expect(store.recoveryWarning, isNotNull);
      preferences.values[LocalStore.savedKey] = '{';
      preferences.values['unrelated'] = 'keep';
      await expectLater(store.saved(), throwsA(failure('local_data_corrupt')));
      await store.clearSaved();
      expect(await store.saved(), isEmpty);
      expect(await store.history(), hasLength(1));
      await store.clearHistory();
      expect(preferences.values['unrelated'], 'keep');
    });
  });
}
