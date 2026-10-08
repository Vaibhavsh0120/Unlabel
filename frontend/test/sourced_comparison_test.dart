import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unlabel/core/accounts/account_data.dart';
import 'package:unlabel/core/network/unlabel_repository.dart';
import 'package:unlabel/core/storage/local_store.dart';

JsonMap fixture(String name) =>
    jsonDecode(File('../contracts/examples/$name').readAsStringSync())
        as JsonMap;

Matcher invalid() => throwsA(isA<AppFailure>());

void main() {
  test(
    'historical options pin original OFF and community tables independently',
    () {
      final report = ProductReport.fromJson(
        fixture('label-report-v1.historical.synthetic.json'),
      );
      final options = sourcedComparisonOptions(report);
      expect(options, hasLength(2));
      expect(options[0].input['kind'], 'off_snapshot');
      expect(options[0].input['barcode'], '0123456789012');
      expect(options[0].input['snapshot_id'], 'synthetic-catalogue');
      expect(options[0].input['selected_table_id'], 'off-table-0');
      expect(options[1].input['kind'], 'community_revision');
      expect(options[1].input['selected_table_id'], 'back-panel');
      expect(options[1].input['factual_sha256'], hasLength(64));
      expect(options[0].label, contains('Open Food Facts'));
      expect(options[1].label, contains('Community'));
      expect(
        sourcedComparisonOptions(
          ProductReport.fromJson(
            fixture('label-report-v1.current.synthetic.json'),
          ),
        ),
        isEmpty,
      );
    },
  );

  test(
    'comparison response rejects duplicate nutrients and invented arithmetic',
    () {
      final raw = fixture('comparison-v1.response.synthetic.json');
      final result = SourcedComparison.fromJson(raw);
      expect(result.rows, hasLength(11));
      expect(result.basisLabel, 'Per 100 g · as sold');
      expect(
        result.rows.singleWhere((row) => row.name == 'sugars').difference,
        0,
      );
      expect(result.a.sourceLabel, contains('2026-10-07'));
      expect(result.a.originalRows, hasLength(1));
      final duplicate = fixture('comparison-v1.response.synthetic.json');
      duplicate['nutrients'][1] = duplicate['nutrients'][0];
      expect(() => SourcedComparison.fromJson(duplicate), invalid());
      final invented = fixture('comparison-v1.response.synthetic.json');
      invented['nutrients'][5]['difference'] = 7.0;
      expect(() => SourcedComparison.fromJson(invented), invalid());
      final incompatible = fixture('comparison-v1.response.synthetic.json');
      incompatible['status'] = 'not_comparable';
      expect(() => SourcedComparison.fromJson(incompatible), invalid());
    },
  );

  test('checkLabel keeps exact confirmation in memory and excludes every serialized report', () async {
    final observation =
        fixture('comparison-v1.request.synthetic.json')['a']['observation']
            as JsonMap;
    final draft = LabelDraft(
      name: observation['identity']['name'] as String,
      rows: const [DraftNutrient(name: 'sugars', value: 12, unit: 'g')],
      basis: const DraftBasis(kind: 'serving', amount: 40, unit: 'g'),
      frontConfirmed: true,
      backConfirmed: true,
      samePackageConfirmed: true,
    );
    final repo = UnlabelRepository(
      baseUrl: 'https://example.test',
      client: MockClient(
        (request) async => http.Response(
          jsonEncode(
            request.url.path == '/v1/meta'
                ? {
                    'api_major': 1,
                    'contract_schema': '1',
                    'report_version': 'label-report-v1',
                    'capabilities': {'label_reports': true},
                  }
                : fixture('label-report-v1.current.synthetic.json'),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    addTearDown(repo.close);
    final report = await repo.checkLabel(draft);
    final option = sourcedComparisonOptions(report).single;
    expect(option.input['observation']['submission_id'], draft.submissionId);
    expect(option.input['observation'], draft.toPayload()['observation']);
    expect(
      () => (option.input['observation'] as JsonMap)['confirmed'] = false,
      throwsUnsupportedError,
    );
    expect(jsonEncode(report.raw), isNot(contains(draft.submissionId)));
    final local = LocalReport(
      id: report.id,
      report: report,
      storedAt: DateTime.now(),
    );
    final account = AccountEntry(
      entryId: newSubmissionId(),
      recordedAt: DateTime.now(),
      report: report,
    );
    expect(jsonEncode(local.toJson()), isNot(contains(draft.submissionId)));
    expect(jsonEncode(account.toJson()), isNot(contains(draft.submissionId)));
    expect(
      sourcedComparisonOptions(LocalReport.fromJson(local.toJson()).report),
      isEmpty,
    );
  });

  test('read-only comparison posts exact pins without authentication and rejects wrong echo', () async {
    final options = sourcedComparisonOptions(
      ProductReport.fromJson(
        fixture('label-report-v1.historical.synthetic.json'),
      ),
    );
    final request = fixture('comparison-v1.request.synthetic.json');
    final response = fixture('comparison-v1.response.synthetic.json');
    final currentA = ComparisonOption.fromInput(
      request['a'] as JsonMap,
      label: 'Current A',
      basis: {'kind': 'serving', 'amount': 40, 'unit': 'g'},
      preparation: 'as_sold',
    );
    var wrongEcho = false;
    final calls = <http.Request>[];
    final repo = UnlabelRepository(
      baseUrl: 'https://example.test',
      client: MockClient((call) async {
        calls.add(call);
        if (call.url.path == '/v1/meta') {
          return http.Response(
            jsonEncode({
              'api_major': 1,
              'contract_schema': '1',
              'report_version': 'label-report-v1',
              'comparison_version': 'sourced-nutrient-comparison-v1',
              'capabilities': {'comparison': true},
            }),
            200,
          );
        }
        expect(call.headers.containsKey('Authorization'), isFalse);
        expect(jsonDecode(call.body)['a'], currentA.input);
        return http.Response(
          jsonEncode({...response, if (wrongEcho) 'input_revision': 2}),
          200,
        );
      }),
    );
    addTearDown(repo.close);
    Future<SourcedComparison> compare() => repo.compare(
      currentA,
      currentA,
      requestId: request['client_request_id'] as String,
      sessionId: request['comparison_session_id'] as String,
      revision: 1,
    );
    expect((await compare()).status, 'partial');
    wrongEcho = true;
    await expectLater(compare(), invalid());
    expect(
      calls.where((call) => call.url.path == '/v1/reports/compare'),
      hasLength(2),
    );
    expect(options, hasLength(2));
  });

  test('source references and their returned source evidence must agree', () {
    final report = ProductReport.fromJson(
      fixture('label-report-v1.historical.synthetic.json'),
    );
    final option = sourcedComparisonOptions(report).first;
    final raw = fixture('comparison-v1.response.synthetic.json');
    for (final side in ['a', 'b']) {
      raw[side]['requested_kind'] = 'off_snapshot';
      raw[side]['assessment_basis'] = 'catalogue_historical';
      raw[side]['requested_reference'] = option.input;
      raw[side]['selected_table_id'] = option.input['selected_table_id'];
      raw[side]['selected_table']['source_table_id'] =
          option.input['selected_table_id'];
      raw[side]['source'] = {
        'kind': 'off_snapshot',
        'source_id': 'off:synthetic-catalogue',
        'manifest': report.raw['resolved']['off_snapshot']['manifest'],
        'provider_source': 'packaging',
        'record_modified_at': null,
        'qualification': 'historical_community_data_not_current_package_proof',
      };
    }
    final result = SourcedComparison.fromJson(raw);
    result.requireRequest(
      option,
      option,
      raw['client_request_id'] as String,
      raw['comparison_session_id'] as String,
      1,
    );
    final bad = jsonDecode(jsonEncode(raw)) as JsonMap;
    bad['a']['source']['manifest']['source_sha256'] = '1' * 64;
    expect(
      () => SourcedComparison.fromJson(bad).requireRequest(
        option,
        option,
        raw['client_request_id'] as String,
        raw['comparison_session_id'] as String,
        1,
      ),
      invalid(),
    );
  });

  test('malformed response types remain bounded app failures', () {
    for (final field in ['reason', 'lower']) {
      final raw = fixture('comparison-v1.response.synthetic.json');
      raw['nutrients'][5][field] = 42;
      expect(() => SourcedComparison.fromJson(raw), invalid());
    }
    final raw = fixture('comparison-v1.response.synthetic.json');
    raw['nutrients'][5]['a']['source_row_ids'] = [42];
    expect(() => SourcedComparison.fromJson(raw), invalid());
  });

  test(
    'malformed historical pins are unavailable without crashing report display',
    () {
      final raw = fixture('label-report-v1.historical.synthetic.json');
      raw['resolved']['community']['revisions'][0]['revision_id'] = 7;
      raw['resolved']['off_snapshot']['manifest']['source_sha256'] = 'wrong';
      expect(sourcedComparisonOptions(ProductReport.fromJson(raw)), isEmpty);
    },
  );
}
