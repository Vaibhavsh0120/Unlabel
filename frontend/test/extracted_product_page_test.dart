import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/app/unlabel_theme.dart';
import 'package:unlabel/core/network/unlabel_repository.dart';
import 'package:unlabel/features/scanner/presentation/extracted_product_page.dart';

class _Repository extends UnlabelRepository {
  _Repository() : super(baseUrl: 'https://example.invalid');
  final submissions = <String>[];
  @override
  Future<ProductReport> checkLabel(LabelDraft draft) async {
    submissions.add(draft.submissionId);
    if (submissions.length == 1) {
      throw const AppFailure('connection', 'Synthetic uncertain write');
    }
    return ProductReport.fromJson(
      jsonDecode(
        File('../contracts/examples/label-report-v1.current.synthetic.json')
            .readAsStringSync(),
      ) as JsonMap,
    );
  }
}

void main() {
  testWidgets(
    'facts need one explicit check; uncertain save retries reuse the submission',
    (tester) async {
      final repository = _Repository();
      addTearDown(repository.close);
      var accepted = 0;
      final label = ExtractedLabel.fromJson(
        jsonDecode(
          File('../contracts/examples/ai-extraction-v1.synthetic.json')
              .readAsStringSync(),
        ) as JsonMap,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: UnlabelTheme.forBrightness(Brightness.light),
          home: ExtractedProductPage(
            label: label,
            repository: repository,
            hasBothSides: true,
            onAccepted: (_) async {
              accepted++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.submissions, isEmpty);
      final button = find.text('These facts match my package');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(repository.submissions, hasLength(1));
      expect(find.text('Synthetic uncertain write'), findsOneWidget);
      expect(accepted, 0);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(repository.submissions, hasLength(2));
      expect(repository.submissions.toSet(), hasLength(1));
      expect(accepted, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
