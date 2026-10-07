import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unlabel/core/network/unlabel_repository.dart';

JsonMap fixture(String name) =>
    jsonDecode(File('../contracts/examples/$name').readAsStringSync())
        as JsonMap;
final metadata = {
  'api_major': 1,
  'contract_schema': '1',
  'report_version': 'label-report-v1',
  'capabilities': {'label_reports': true, 'catalogue_search': true},
};
JsonMap searchPage(String query) => {
  'schema_version': '1',
  'search_version': 'catalogue-search-v1',
  'status': 'ready',
  'normalized_query': query,
  'candidates': [],
  'next_cursor': null,
  'matched_count': 0,
  'ambiguous': false,
  'warnings': [],
};

void main() {
  test(
    'concurrent and repeated public reads share GETs until fixed expiry',
    () async {
      var now = DateTime.utc(2026, 10, 8);
      final pending = Completer<http.Response>();
      var reads = 0, metas = 0;
      final repository = UnlabelRepository(
        baseUrl: 'https://example.test',
        clock: () => now,
        client: MockClient((request) async {
          if (request.url.path == '/v1/meta') {
            metas++;
            return http.Response(jsonEncode(metadata), 200);
          }
          reads++;
          if (reads == 1) return pending.future;
          return http.Response(jsonEncode(searchPage('oats')), 200);
        }),
      );
      addTearDown(repository.close);
      final first = repository.search('oats');
      final second = repository.search('oats');
      await Future<void>.delayed(Duration.zero);
      expect(reads, 1);
      expect(metas, 1);
      pending.complete(http.Response(jsonEncode(searchPage('oats')), 200));
      await Future.wait([first, second]);
      await repository.search('oats');
      expect(reads, 1);
      now = now.add(const Duration(seconds: 60));
      await repository.search('oats');
      expect(reads, 2);
    },
  );

  test('failed reads retry and search LRU remains bounded', () async {
    var reads = 0;
    var fail = true;
    final repository = UnlabelRepository(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        if (request.url.path == '/v1/meta') {
          return http.Response(jsonEncode(metadata), 200);
        }
        reads++;
        if (fail) return http.Response('{}', 503);
        return http.Response(
          jsonEncode(searchPage(request.url.queryParameters['q']!)),
          200,
        );
      }),
    );
    addTearDown(repository.close);
    await expectLater(repository.search('first'), throwsA(isA<AppFailure>()));
    fail = false;
    await repository.search('first');
    expect(reads, 2);
    for (var i = 0; i < 20; i++) {
      await repository.search('query$i');
    }
    await repository.search('first');
    expect(reads, 23);
  });

  test(
    'historical reports are cached, current POST analyses remain independent',
    () async {
      var now = DateTime.utc(2026, 10, 8);
      var reads = 0, writes = 0;
      final repository = UnlabelRepository(
        baseUrl: 'https://example.test',
        clock: () => now,
        client: MockClient((request) async {
          if (request.url.path == '/v1/meta') {
            return http.Response(jsonEncode(metadata), 200);
          }
          if (request.method == 'POST') {
            writes++;
            return http.Response.bytes(
              utf8.encode(
                jsonEncode(fixture('label-report-v1.current.synthetic.json')),
              ),
              200,
            );
          }
          reads++;
          return http.Response.bytes(
            utf8.encode(
              jsonEncode(fixture('label-report-v1.historical.synthetic.json')),
            ),
            200,
          );
        }),
      );
      addTearDown(repository.close);
      await Future.wait([
        repository.loadReport('0123456789012'),
        repository.loadReport('0123456789012'),
      ]);
      expect(reads, 1);
      await repository.loadReport('0123456789012');
      expect(reads, 1);
      now = now.add(const Duration(minutes: 5));
      await repository.loadReport('0123456789012');
      expect(reads, 2);
      final draft = LabelDraft(
        name: 'Synthetic oats',
        ingredients: const DraftSection(
          status: 'present',
          text: 'Oats',
          complete: true,
        ),
        frontConfirmed: true,
        backConfirmed: true,
        samePackageConfirmed: true,
        observedAt: now,
      );
      await repository.checkLabel(draft);
      await repository.checkLabel(draft);
      expect(writes, 2);
      repository.close();
      await expectLater(repository.search('oats'), throwsA(isA<AppFailure>()));
    },
  );
}
