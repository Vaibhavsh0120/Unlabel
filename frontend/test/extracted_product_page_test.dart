import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/app/unlabel_theme.dart';
import 'package:unlabel/core/network/unlabel_repository.dart';
import 'package:unlabel/features/scanner/presentation/product_info_page.dart';

class _Repository extends UnlabelRepository {
  _Repository() : super(baseUrl: 'https://example.invalid');
  int submissions = 0;
  @override
  Future<ProductReport> checkLabel(LabelDraft draft) async {
    submissions++;
    throw StateError('A machine reading must never submit a confirmed draft.');
  }

  @override
  Future<LiveProductLookup> liveProduct(String barcode) async =>
      const LiveProductLookup('disabled');
  @override
  Future<MachineProductLookup> machineProduct(String barcode) async =>
      const MachineProductLookup([], []);
}

void main() {
  testWidgets(
    'automatic shared receipt is qualified without a confirmation action or write',
    (tester) async {
      final repository = _Repository();
      addTearDown(repository.close);
      final label = ExtractedLabel.fromJson(
        jsonDecode(
          File('../contracts/examples/ai-extraction-v1.synthetic.json')
              .readAsStringSync(),
        ) as JsonMap,
        contribution: {
          'schema_version': 'machine-label-contribution-v1',
          'evidence': 'machine_extracted_unverified',
          'status': 'shared_unverified',
          'observation_id': 'a' * 64,
          'barcode': '8901764051258',
          'conflict_fields': ['ingredients'],
          'reason': null,
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: UnlabelTheme.forBrightness(Brightness.light),
          home: ProductInfoPage.extracted(label: label, repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('Product info'), findsOneWidget);
      expect(find.text('Product reading added automatically'), findsOneWidget);
      expect(
        find.textContaining('disagree with other sources'),
        findsOneWidget,
      );
      expect(find.text('These facts match my package'), findsNothing);
      expect(repository.submissions, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
