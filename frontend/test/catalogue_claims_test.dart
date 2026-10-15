import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unlabel/core/network/unlabel_repository.dart';
import 'package:unlabel/features/scanner/presentation/product_info_page.dart';

const code = '8901764051258';
JsonMap response() => {
  'schema_version': 'catalogue-claim-check-v1',
  'barcode': code,
  'status': 'ready',
  'assessment_basis': 'catalogue_historical',
  'knowledge_version': 'synthetic',
  'source_ids': ['synthetic-source'],
  'warnings': ['not_legal_certification'],
  'assessments': [
    {
      'text': 'High protein',
      'claim': 'high_protein',
      'status': 'insufficient_information',
      'reasons': [
        'current_package_not_confirmed',
        'food_category_and_form_not_established',
      ],
      'rule_source_ids': ['synthetic-rule-source'],
      'comparisons': [
        {
          'source_id': 'synthetic-source',
          'table_id': 'back-panel',
          'criterion_id': 'synthetic-protein',
          'basis': 'per_100_g',
          'nutrient': 'protein',
          'operator': 'gte',
          'threshold': 12,
          'unit': 'g',
          'value': 14,
          'outcome': 'pass',
        },
      ],
    },
  ],
};

class _Repository extends UnlabelRepository {
  _Repository() : super(baseUrl: 'https://example.test');
  int writes = 0;
  @override
  Future<CatalogueClaimCheck> catalogueClaims(
    String barcode,
    List<String> claims,
  ) async => CatalogueClaimCheck.fromJson(response(), barcode, claims);
  @override
  Future<LiveProductLookup> liveProduct(String barcode) async =>
      const LiveProductLookup('disabled');
  @override
  Future<MachineProductLookup> machineProduct(String barcode) async =>
      const MachineProductLookup([], []);
  @override
  Future<ProductReport> checkLabel(LabelDraft draft) async {
    writes++;
    throw StateError(
      'Read-only claim checks must never confirm an AI reading.',
    );
  }
}

void main() {
  test(
    'catalogue check sends only selected barcode and photographed claims',
    () async {
      var calls = 0;
      final repository = UnlabelRepository(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          calls++;
          expect(request.url.path, '/v1/claims/catalogue-check');
          expect(request.method, 'POST');
          expect(request.followRedirects, isFalse);
          expect(jsonDecode(request.body), {
            'barcode': code,
            'claims': ['High protein'],
          });
          return http.Response(jsonEncode(response()), 200);
        }),
      );
      addTearDown(repository.close);
      final value = await repository.catalogueClaims(code, ['High protein']);
      expect(value.assessments.single['status'], 'insufficient_information');
      expect(calls, 1);
    },
  );

  test('checks reject a different SKU, injected claim, fabricated verdict and invalid number', () {
    for (final mutate in <void Function(JsonMap)>[
      (v) => v['barcode'] = '012345678905',
      (v) => v['assessments'][0]['text'] = 'Sugar free',
      (v) => v['assessments'][0]['status'] = 'supported',
      (v) => v['assessments'][0]['comparisons'][0]['value'] = double.infinity,
    ]) {
      final raw = response();
      mutate(raw);
      expect(
        () => CatalogueClaimCheck.fromJson(raw, code, ['High protein']),
        throwsA(isA<AppFailure>()),
      );
    }
  });

  testWidgets(
    'a numeric source comparison stays qualified and never submits confirmed facts',
    (tester) async {
      final raw = jsonDecode(
        File('../contracts/examples/ai-extraction-v1.synthetic.json')
            .readAsStringSync(),
      ) as JsonMap;
      raw['identity']['barcode'] = code;
      raw['front_claims'] = ['High protein'];
      final repository = _Repository();
      addTearDown(repository.close);
      await tester.pumpWidget(
        MaterialApp(
          home: ProductInfoPage.extracted(
            label: ExtractedLabel.fromJson(raw),
            repository: repository,
            barcode: code,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Front claims and catalogue evidence'), findsOneWidget);
      expect(
        find.text('Insufficient information for this claim'),
        findsOneWidget,
      );
      final numbers = find.text('Sourced numbers and criteria');
      await tester.ensureVisible(numbers);
      await tester.tap(numbers);
      await tester.pumpAndSettle();
      expect(find.text('protein: 14 g'), findsOneWidget);
      expect(
        find.textContaining('synthetic-source · back-panel'),
        findsOneWidget,
      );
      expect(repository.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
