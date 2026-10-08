import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/core/models/extracted_label.dart';
import 'package:unlabel/core/models/extracted_observation.dart';

Map<String, dynamic> fixture() => jsonDecode(
  File('../contracts/examples/ai-extraction-v1.synthetic.json')
      .readAsStringSync(),
) as Map<String, dynamic>;

void main() {
  test('acceptance preserves basis, drops bounds and never infers allergen absence', () {
    final label = ExtractedLabel.fromJson(fixture());
    final draft = acceptedLabelDraft(label)!;
    expect(draft.rows.map((row) => row.name), ['sugars', 'protein']);
    expect(draft.rows.last.value, isNull);
    expect(draft.basis.amount, 100);
    expect(draft.basis.unit, 'g');
    expect(draft.mayContain.status, 'not_captured');
    expect(draft.ingredients.complete, isFalse);
    expect(
      draft.frontConfirmed && draft.backConfirmed && draft.samePackageConfirmed,
      isTrue,
    );
  });
  test('all duplicated nutrient rows stay unresolved, including qualified duplicates', () {
    final value = fixture();
    final rows = value['nutrition_tables'][0]['rows'] as List;
    rows.add({...Map<String, dynamic>.from(rows.first as Map), 'value': 9});
    final draft = acceptedLabelDraft(ExtractedLabel.fromJson(value))!;
    expect(draft.rows.map((row) => row.name), ['protein']);
    expect(draft.ingredients.text, isNotEmpty);
  });
  test('barcode conflict and unknown preparation cannot silently become confirmed facts', () {
    final value = fixture();
    expect(
      acceptedLabelDraft(
        ExtractedLabel.fromJson(value),
        barcode: '8901764051259',
      ),
      isNull,
    );
    value['nutrition_tables'][0]['preparation'] = 'unknown';
    final label = ExtractedLabel.fromJson(value);
    expect(acceptedLabelDraft(label), isNull);
    expect(
      acceptedLabelDraft(label, preparation: 'as_prepared')?.preparation,
      'as_prepared',
    );
    expect(
      acceptedLabelDraft(label, preparation: 'as_sold', tableIndex: 3),
      isNull,
    );
  });
}
