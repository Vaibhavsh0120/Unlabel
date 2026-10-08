import '../models/extracted_label.dart';
import '../models/product_report.dart' show JsonMap;
import 'label_text_suggestions.dart';

/// Conservative fallback: ambiguous columns and missing bases stay unavailable.
ExtractedLabel readLocalLabel(String front, String back) {
  final sections = LabelTextSuggestions.fromText(front, back);
  final claims = <String>[];
  final claimPattern = RegExp(
    r'\b(?:no added sugar|low sugar|sugar free|high fibre|high fiber|source of fibre|source of fiber|high protein|source of protein)\b',
    caseSensitive: false,
  );
  for (final line in front.split('\n')) {
    if (line.trim().length <= 256 &&
        claimPattern.hasMatch(line) &&
        claims.length < 16) {
      claims.add(line.trim());
    }
  }
  final basisPattern = RegExp(
    r'\bper\s*(100(?:\.0)?|\d+(?:\.\d+)?)\s*(g|ml)\b',
    caseSensitive: false,
  );
  final bases = basisPattern
      .allMatches(back)
      .map((m) => '${m[1]}:${m[2]!.toLowerCase()}')
      .toSet();
  final rows = <JsonMap>[];
  final seen = <String>{};
  final duplicates = <String>{};
  const names = {
    'energy': 'energy',
    'calories': 'energy',
    'total fat': 'fat',
    'fat': 'fat',
    'saturated fat': 'saturated_fat',
    'carbohydrate': 'carbohydrates',
    'carbohydrates': 'carbohydrates',
    'total carbohydrate': 'carbohydrates_total',
    'total carbohydrates': 'carbohydrates_total',
    'sugar': 'sugars',
    'sugars': 'sugars',
    'total sugar': 'sugars',
    'total sugars': 'sugars',
    'added sugar': 'added_sugars',
    'added sugars': 'added_sugars',
    'dietary fibre': 'fibre',
    'dietary fiber': 'fibre',
    'fibre': 'fibre',
    'fiber': 'fibre',
    'protein': 'protein',
    'sodium': 'sodium',
    'salt': 'salt',
  };
  final rowPattern = RegExp(
    r'^\s*([A-Za-z ]+?)\s*[:\-]?\s*([<≤~]?)\s*(\d+(?:\.\d+)?)\s*(kcal|kj|mg|g)\s*$',
    caseSensitive: false,
  );
  if (bases.length == 1) {
    for (final line in back.split('\n')) {
      final match = rowPattern.firstMatch(line);
      if (match == null) continue;
      final nutrient = names[match[1]!.trim().toLowerCase()];
      final value = double.tryParse(match[3]!);
      final unit = match[4]!.toLowerCase() == 'kj'
          ? 'kJ'
          : match[4]!.toLowerCase();
      if (nutrient == null ||
          value == null ||
          !value.isFinite ||
          value > 1000000 ||
          (nutrient == 'energy') != const ['kcal', 'kJ'].contains(unit)) {
        continue;
      }
      if (!seen.add(nutrient)) duplicates.add(nutrient);
      rows.add({
        'nutrient': nutrient,
        'value': value,
        'unit': unit,
        'qualifier': switch (match[2]) {
          '<' => 'less_than',
          '≤' => 'less_than_or_equal',
          '~' => 'approximate',
          _ => 'exact',
        },
        'printed_text': line.trim(),
      });
    }
  }
  rows.removeWhere((row) => duplicates.contains(row['nutrient']));
  final basis = bases.length == 1 ? bases.single.split(':') : null;
  return ExtractedLabel.fromJson({
    'schema_version': '1',
    'evidence': 'machine_extracted_unverified',
    'identity': {
      'name': sections.name,
      'brand': null,
      'variant': null,
      'quantity': null,
      'barcode': null,
    },
    'ingredients': sections.ingredients,
    'contains': sections.contains,
    'may_contain': sections.mayContain,
    'front_claims': claims,
    'regions': <JsonMap>[],
    'nutrition_tables': rows.isEmpty
        ? <JsonMap>[]
        : [
            {
              'table_id': 'local-back-table',
              'preparation': 'unknown',
              'basis': {
                'kind': 'quantity',
                'amount': double.parse(basis![0]),
                'unit': basis[1] == 'ml' ? 'mL' : 'g',
                'printed_text': 'Per ${basis[0]} ${basis[1]}',
              },
              'rows': rows.take(32).toList(),
            },
          ],
  });
}
