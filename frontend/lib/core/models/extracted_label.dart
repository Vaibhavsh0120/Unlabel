import 'dart:collection';
import 'dart:ui';

import 'app_failure.dart';
import 'product_report.dart' show JsonMap;

const _slots = ['front', 'back', 'barcode'];
const extractedNutrients = [
  'energy',
  'fat',
  'saturated_fat',
  'carbohydrates',
  'carbohydrates_total',
  'sugars',
  'added_sugars',
  'fibre',
  'protein',
  'sodium',
  'salt',
];

void _check(bool valid) {
  if (!valid) {
    throw const AppFailure(
      'invalid_response',
      'The label could not be read reliably. Try a clearer photo.',
    );
  }
}

void _keys(JsonMap raw, List<String> expected) =>
    _check(raw.length == expected.length && expected.every(raw.containsKey));

bool _text(Object? value, int maximum, {bool nullable = false}) =>
    nullable && value == null ||
    value is String && value.trim().isNotEmpty && value.length <= maximum;
bool _number(Object? value, double maximum, {bool positive = false}) =>
    value is num &&
    value.isFinite &&
    (positive ? value > 0 : value >= 0) &&
    value <= maximum;

Object? _freeze(Object? value, [int depth = 0]) {
  _check(depth <= 16);
  if (value is JsonMap) {
    return UnmodifiableMapView<String, dynamic>(
      value.map((k, v) => MapEntry(k, _freeze(v, depth + 1))),
    );
  }
  if (value is List) {
    return List<dynamic>.unmodifiable(value.map((v) => _freeze(v, depth + 1)));
  }
  return value;
}

class ExtractedRegion {
  const ExtractedRegion({
    required this.slot,
    required this.label,
    required this.text,
    required this.box,
  });
  factory ExtractedRegion.fromJson(JsonMap raw) {
    _keys(raw, ['slot', 'label', 'text', 'box']);
    _check(
      _slots.contains(raw['slot']) &&
          const [
            'identity',
            'claim',
            'ingredients',
            'nutrition',
            'allergen',
            'barcode',
          ].contains(raw['label']) &&
          _text(raw['text'], 512) &&
          raw['box'] is JsonMap,
    );
    final box = raw['box'] as JsonMap;
    _keys(box, ['top', 'left', 'bottom', 'right']);
    _check(
      ['top', 'left', 'bottom', 'right'].every((key) => _number(box[key], 1)),
    );
    final rect = Rect.fromLTRB(
      (box['left'] as num).toDouble(),
      (box['top'] as num).toDouble(),
      (box['right'] as num).toDouble(),
      (box['bottom'] as num).toDouble(),
    );
    _check(rect.width > 0 && rect.height > 0);
    return ExtractedRegion(
      slot: raw['slot'],
      label: raw['label'],
      text: raw['text'],
      box: rect,
    );
  }
  final String slot, label, text;

  /// Normalized upright-photo coordinates, top-left origin.
  final Rect box;
  JsonMap toJson() => {
    'slot': slot,
    'label': label,
    'text': text,
    'box': {
      'top': box.top,
      'left': box.left,
      'bottom': box.bottom,
      'right': box.right,
    },
  };
}

class ExtractedLabel {
  ExtractedLabel._(this.json, this.regions, this.storageStatus);
  factory ExtractedLabel.fromJson(JsonMap raw, {String? storageStatus}) {
    _check(
      storageStatus == null ||
          const ['private_unverified', 'not_stored'].contains(storageStatus),
    );
    _keys(raw, [
      'schema_version',
      'evidence',
      'identity',
      'ingredients',
      'contains',
      'may_contain',
      'front_claims',
      'nutrition_tables',
      'regions',
    ]);
    _check(
      raw['schema_version'] == '1' &&
          raw['evidence'] == 'machine_extracted_unverified',
    );
    _check(raw['identity'] is JsonMap);
    final identity = raw['identity'] as JsonMap;
    _keys(identity, ['name', 'brand', 'variant', 'quantity', 'barcode']);
    for (final key in ['name', 'brand', 'variant', 'quantity']) {
      _check(
        identity.containsKey(key) && _text(identity[key], 256, nullable: true),
      );
    }
    _check(
      identity.containsKey('barcode') &&
          (identity['barcode'] == null ||
              identity['barcode'] is String &&
                  validProductBarcode(identity['barcode'])),
    );
    for (final key in ['ingredients', 'contains', 'may_contain']) {
      _check(raw.containsKey(key) && _text(raw[key], 16000, nullable: true));
    }
    final claims = raw['front_claims'];
    final tables = raw['nutrition_tables'];
    final regions = raw['regions'];
    _check(
      claims is List &&
          claims.length <= 16 &&
          claims.every((v) => _text(v, 256)),
    );
    _check(
      tables is List &&
          tables.length <= 3 &&
          regions is List &&
          regions.length <= 160,
    );
    final ids = <String>{};
    for (final value in tables as List) {
      _check(value is JsonMap);
      final table = value as JsonMap;
      _keys(table, ['table_id', 'preparation', 'basis', 'rows']);
      _check(
        _text(table['table_id'], 64) &&
            ids.add(table['table_id']) &&
            const [
              'as_sold',
              'as_prepared',
              'unknown',
            ].contains(table['preparation']) &&
            table['basis'] is JsonMap,
      );
      final basis = table['basis'] as JsonMap;
      _keys(basis, ['kind', 'printed_text', 'amount', 'unit']);
      _check(
        const ['quantity', 'serving'].contains(basis['kind']) &&
            _text(basis['printed_text'], 512),
      );
      _check((basis['amount'] == null) == (basis['unit'] == null));
      _check(basis['kind'] != 'quantity' || basis['amount'] != null);
      _check(
        basis['amount'] == null ||
            _number(basis['amount'], 100000, positive: true),
      );
      _check(
        basis['unit'] == null || const ['g', 'mL'].contains(basis['unit']),
      );
      _check(
        table['rows'] is List &&
            (table['rows'] as List).isNotEmpty &&
            (table['rows'] as List).length <= 32,
      );
      for (final value in table['rows'] as List) {
        _check(value is JsonMap);
        final row = value as JsonMap;
        _keys(row, ['nutrient', 'unit', 'qualifier', 'printed_text', 'value']);
        _check(
          extractedNutrients.contains(row['nutrient']) &&
              const ['g', 'mg', 'ug', 'kcal', 'kJ'].contains(row['unit']) &&
              const [
                'exact',
                'less_than',
                'less_than_or_equal',
                'approximate',
                'unknown',
              ].contains(row['qualifier']) &&
              _text(row['printed_text'], 512),
        );
        _check((row['value'] == null) == (row['qualifier'] == 'unknown'));
        _check(row['value'] == null || _number(row['value'], 1000000));
        _check(
          const ['kcal', 'kJ'].contains(row['unit']) ==
              (row['nutrient'] == 'energy'),
        );
      }
    }
    final boxes = <ExtractedRegion>[];
    for (final value in regions as List) {
      _check(value is JsonMap);
      boxes.add(ExtractedRegion.fromJson(value as JsonMap));
    }
    return ExtractedLabel._(
      _freeze(raw) as JsonMap,
      List.unmodifiable(boxes),
      storageStatus,
    );
  }
  final JsonMap json;
  final List<ExtractedRegion> regions;
  final String? storageStatus;
  JsonMap get identity => json['identity'] as JsonMap;
  String? get ingredients => json['ingredients'] as String?;
  String? get contains => json['contains'] as String?;
  String? get mayContain => json['may_contain'] as String?;
  List<String> get frontClaims =>
      List<String>.unmodifiable((json['front_claims'] as List).cast<String>());
  List<JsonMap> get nutritionTables => List<JsonMap>.unmodifiable(
    (json['nutrition_tables'] as List).cast<JsonMap>(),
  );
  bool get hasFacts =>
      ingredients != null ||
      nutritionTables.isNotEmpty ||
      identity['name'] != null ||
      frontClaims.isNotEmpty;
}

bool validProductBarcode(String value) {
  if (!RegExp(r'^(?:[0-9]{8}|[0-9]{12,14})$').hasMatch(value)) return false;
  var sum = 0;
  for (
    var i = value.length - 2, weight = 3;
    i >= 0;
    i--, weight = weight == 3 ? 1 : 3
  ) {
    sum += (value.codeUnitAt(i) - 48) * weight;
  }
  return (10 - sum % 10) % 10 == value.codeUnitAt(value.length - 1) - 48;
}
