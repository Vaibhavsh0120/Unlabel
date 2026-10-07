import 'dart:collection';

import 'app_failure.dart';

typedef JsonMap = Map<String, dynamic>;

JsonMap _map(Object? value) => value is Map<String, dynamic> ? value : {};
List<dynamic> _list(Object? value) => value is List ? value : const [];
String? _text(Object? value) =>
    value is String && value.isNotEmpty ? value : null;
double? _number(Object? value) =>
    value is num && value.isFinite ? value.toDouble() : null;
List<String> _strings(Object? value) =>
    _list(value).whereType<String>().toList(growable: false);

Object? _freeze(Object? value, [int depth = 0]) {
  if (depth > 32) {
    throw const AppFailure(
      'invalid_response',
      'The service returned data we could not read. Please try again.',
    );
  }
  if (value is Map<String, dynamic>) {
    return UnmodifiableMapView<String, dynamic>(
      value.map((key, item) => MapEntry(key, _freeze(item, depth + 1))),
    );
  }
  if (value is List) {
    return List<dynamic>.unmodifiable(
      value.map((item) => _freeze(item, depth + 1)),
    );
  }
  return value;
}

String basisDescription(Object? value, [Object? preparation]) {
  final basis = _map(value);
  final amount = _number(basis['amount']);
  final unit = _text(basis['unit']);
  final measurement = amount != null && unit != null
      ? '${formatNumber(amount)} $unit'
      : null;
  final base = basis['kind'] == 'serving'
      ? 'Per serving${measurement == null ? ' (size unknown)' : ' ($measurement)'}'
      : measurement == null
      ? 'Basis unknown'
      : 'Per $measurement';
  return '$base${preparation == 'as_prepared'
      ? ' · as prepared'
      : preparation == 'as_sold'
      ? ' · as sold'
      : ''}';
}

String formatNumber(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value
          .toStringAsFixed(2)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');

void _require(bool valid) {
  if (!valid) {
    throw const AppFailure(
      'invalid_response',
      'The service returned a report we could not read. Please try again.',
    );
  }
}

bool _validText(Object? value, int maximum, {bool nullable = false}) =>
    (nullable && value == null) ||
    (value is String && value.trim().isNotEmpty && value.length <= maximum);
bool _stringList(Object? value, int maximum, {int textMaximum = 256}) =>
    value is List &&
    value.length <= maximum &&
    value.every((item) => _validText(item, textMaximum));
bool _finiteValue(Object? value) =>
    value == null ||
    (value is num && value.isFinite && value >= 0 && value <= 1000000000);

void _validateBasis(Object? value, {bool nullable = false}) {
  if (value == null && nullable) return;
  _require(value is JsonMap);
  final basis = value as JsonMap;
  _require(const ['quantity', 'serving'].contains(basis['kind']));
  final amount = basis['amount'];
  final unit = basis['unit'];
  _require((amount == null) == (unit == null));
  _require(basis['kind'] != 'quantity' || amount != null);
  _require(
    amount == null ||
        (amount is num && amount.isFinite && amount > 0 && amount <= 100000),
  );
  _require(unit == null || const ['g', 'mL'].contains(unit));
}

void _validateDisplayContract(JsonMap raw) {
  _require(
    _stringList(raw['warnings'], 100) &&
        _stringList(raw['missing_inputs'], 100),
  );
  for (final name in ['ingredients', 'contains', 'may_contain']) {
    final section = _map(raw[name]);
    _require(
      const [
        'present',
        'not_observed',
        'not_captured',
        'unknown',
        'conflict',
        'not_comparable',
      ].contains(section['status']),
    );
    _require(
      section['status'] == 'present'
          ? _validText(section['text'], 16000)
          : section['text'] == null,
    );
    _require(
      section['completeness'] == null ||
          const ['complete', 'partial'].contains(section['completeness']),
    );
    _require(_stringList(section['source_ids'], 9));
  }
  _require(
    const [
      'saved',
      'authentication_required',
      'unavailable',
      'rate_limited',
      'conflict',
      'needs_correction',
      'read_only',
    ].contains(_map(raw['storage'])['status']),
  );
  final storage = _map(raw['storage']);
  _require(_stringList(storage['warnings'], 100));
  _require((storage['status'] == 'saved') == (storage['receipt'] is JsonMap));
  final historical = raw['assessment_basis'] == 'catalogue_historical';
  if (historical) {
    _require(
      raw['resolved'] is JsonMap &&
          raw['observation'] == null &&
          raw['nutrition'] == null,
    );
    final resolved = _map(raw['resolved']);
    _require(
      _validText(resolved['requested_barcode'], 14) &&
          resolved['fields'] is List &&
          _list(resolved['fields']).length <= 128 &&
          resolved['community'] is JsonMap,
    );
    _require(
      raw['resolved_nutrients'] is List &&
          _list(raw['resolved_nutrients']).length <= 128,
    );
    for (final item in _list(raw['resolved_nutrients'])) {
      _require(item is JsonMap);
      final field = item as JsonMap;
      _require(
        _validText(field['field'], 256) &&
            const [
              'unknown',
              'single_source',
              'agreement',
              'conflict',
              'not_comparable',
            ].contains(field['state']),
      );
      _require(
        _finiteValue(field['value']) && _stringList(field['source_ids'], 9),
      );
      _require(
        field['unit'] == null || const ['g', 'kcal'].contains(field['unit']),
      );
      _validateBasis(field['basis'], nullable: true);
      _require(
        field['value'] == null ||
            (const ['single_source', 'agreement'].contains(field['state']) &&
                _list(field['source_ids']).isNotEmpty &&
                field['evidence_state'] is String),
      );
    }
  } else {
    _require(
      raw['identity'] is JsonMap &&
          raw['observation'] is JsonMap &&
          raw['nutrition'] is JsonMap &&
          raw['resolved'] == null,
    );
    final identity = _map(raw['identity']);
    _require(_validText(identity['name'], 256));
    for (final key in ['brand', 'variant', 'quantity']) {
      _require(_validText(identity[key], 128, nullable: true));
    }
    final nutrition = _map(raw['nutrition']);
    _require(
      nutrition['tables'] is List && _list(nutrition['tables']).length <= 64,
    );
    for (final item in _list(nutrition['tables'])) {
      _require(item is JsonMap);
      final table = item as JsonMap;
      _validateBasis(table['normalized_basis']);
      _require(
        const ['as_sold', 'as_prepared'].contains(table['preparation']) &&
            table['nutrients'] is JsonMap,
      );
      for (final cellValue in _map(table['nutrients']).values) {
        _require(cellValue is JsonMap);
        final cell = cellValue as JsonMap;
        _require(
          _finiteValue(cell['value']) &&
              const ['g', 'kcal'].contains(cell['unit']),
        );
      }
    }
  }
  _require(raw['claims'] is List && _list(raw['claims']).length <= 16);
  for (final item in _list(raw['claims'])) {
    _require(item is JsonMap && _validText(_map(item)['printed_text'], 256));
    final assessment = _map(item)['assessment'];
    _require(
      assessment == null ||
          (assessment is JsonMap &&
              _validText(assessment['explanation'], 4000) &&
              const [
                'supported',
                'contradicted',
                'insufficient_information',
              ].contains(assessment['status'])),
    );
    _require(!historical || assessment == null);
  }
  _require(
    raw['ingredient_insights'] is List &&
        _list(raw['ingredient_insights']).length <= 64,
  );
  for (final item in _list(raw['ingredient_insights'])) {
    final entry = _map(_map(item)['entry']);
    _require(
      item is JsonMap &&
          _validText(entry['name_en'], 256) &&
          _validText(entry['function_en'], 256) &&
          _stringList(entry['source_ids'], 3),
    );
  }
  if (raw['sugar'] != null) {
    _require(raw['sugar'] is JsonMap);
    final sugar = _map(raw['sugar']);
    _require(
      sugar['approximation_version'] == 'sugar-cubes-4g-v1' &&
          sugar['assessment_basis'] == raw['assessment_basis'] &&
          sugar['approximation'] == true &&
          sugar['grams_per_cube'] == 4,
    );
    _require(
      sugar['sugars_g'] != null &&
          _finiteValue(sugar['sugars_g']) &&
          sugar['cubes'] != null &&
          _finiteValue(sugar['cubes']),
    );
    _validateBasis(sugar['basis']);
  }
}

class ReportSection {
  ReportSection.fromJson(JsonMap value)
    : status = _text(value['status']) ?? 'unknown',
      text = value['status'] == 'present' ? _text(value['text']) : null,
      completeness = _text(value['completeness']),
      sourceIds = List.unmodifiable(_strings(value['source_ids'])),
      evidenceState = _text(value['evidence_state']);
  final String status;
  final String? text;
  final String? completeness;
  final List<String> sourceIds;
  final String? evidenceState;
}

class ReportNutrient {
  const ReportNutrient({
    required this.name,
    required this.value,
    required this.unit,
    required this.basisLabel,
    required this.state,
    this.sourceIds = const [],
    this.evidenceState,
    this.observedOn,
    this.sourceUpdatedAt,
  });
  final String name;
  final double? value;
  final String unit;
  final String basisLabel;
  final String state;
  final List<String> sourceIds;
  final String? evidenceState;
  final String? observedOn;
  final String? sourceUpdatedAt;
}

class SugarView {
  SugarView.fromJson(JsonMap value)
    : grams = _number(value['sugars_g'])!,
      cubes = _number(value['cubes'])!,
      basisLabel = basisDescription(value['basis'], value['preparation']);
  final double grams;
  final double cubes;
  final String basisLabel;
}

class ReportClaimView {
  ReportClaimView.fromJson(JsonMap value)
    : text = _text(value['printed_text']) ?? 'Unidentified claim',
      status =
          _text(_map(value['assessment'])['status']) ?? 'insufficient_evidence',
      reason =
          _text(_map(value['assessment'])['explanation']) ??
          'Current confirmed facts and claim context are needed to check this claim.';
  final String text;
  final String status;
  final String reason;
}

class IngredientInsight {
  IngredientInsight.fromJson(JsonMap value)
    : name = _text(_map(value['entry'])['name_en']) ?? 'Ingredient',
      nameHi = _text(_map(value['entry'])['name_hi']),
      function =
          _text(_map(value['entry'])['function_en']) ?? 'Function unavailable',
      functionHi = _text(_map(value['entry'])['function_hi']),
      matchedText = _text(value['matched_text']) ?? '',
      sourceIds = List.unmodifiable(
        _strings(_map(value['entry'])['source_ids']),
      );
  final String name;
  final String? nameHi;
  final String function;
  final String? functionHi;
  final String matchedText;
  final List<String> sourceIds;
}

/// Retains the complete source contract without allowing UI mutation. Display
/// helpers never turn an unavailable field or conflict into a selected value.
class ProductReport {
  ProductReport.fromJson(JsonMap value) : raw = _freeze(value) as JsonMap {
    if (raw['schema_version'] != '1' ||
        raw['report_version'] != 'label-report-v1' ||
        !const ['ready', 'partial'].contains(raw['status']) ||
        !const [
          'user_confirmed_label',
          'catalogue_historical',
        ].contains(raw['assessment_basis']) ||
        raw['ingredients'] is! Map ||
        raw['contains'] is! Map ||
        raw['may_contain'] is! Map ||
        raw['storage'] is! Map ||
        DateTime.tryParse(_text(raw['generated_at']) ?? '') == null) {
      throw const AppFailure(
        'invalid_response',
        'The service returned a report we could not read. Please try again.',
      );
    }
    _validateDisplayContract(raw);
  }
  final JsonMap raw;
  bool get isHistorical => raw['assessment_basis'] == 'catalogue_historical';
  String get status => raw['status'] as String;
  String get storageStatus =>
      _text(_map(raw['storage'])['status']) ?? 'unavailable';
  List<String> get warnings => _strings(raw['warnings']);
  List<String> get missingInputs => _strings(raw['missing_inputs']);
  String? get barcode =>
      _text(_map(raw['observation'])['barcode']) ??
      _text(_map(raw['resolved'])['requested_barcode']);
  String get id => barcode == null
      ? 'label:${raw['generated_at']}:$name'
      : 'barcode:$barcode';

  String? _identity(String field, String offField) {
    final direct = _text(_map(raw['identity'])[field]);
    if (direct != null) return direct;
    final resolved = _map(raw['resolved']);
    for (final item in _list(resolved['fields'])) {
      final selected = _map(item);
      if (selected['field'] == 'identity.$field') {
        // A conflicting resolved field must not fall back to one source.
        if (const ['conflict', 'not_comparable'].contains(selected['state'])) {
          return null;
        }
        return _text(selected['value']);
      }
    }
    return _text(_map(_map(resolved['off_snapshot'])['product'])[offField]);
  }

  String get name => _identity('name', 'name') ?? 'Product name unavailable';
  String? get brand => _identity('brand', 'brands');
  String? get variant => _identity('variant', 'variant');
  String? get quantity => _identity('quantity', 'quantity_text');
  String get basisLabel => isHistorical
      ? 'Dated catalogue information'
      : 'Your confirmed package label';
  ReportSection get ingredients =>
      ReportSection.fromJson(_map(raw['ingredients']));
  ReportSection get contains => ReportSection.fromJson(_map(raw['contains']));
  ReportSection get mayContain =>
      ReportSection.fromJson(_map(raw['may_contain']));
  SugarView? get sugar {
    final value = _map(raw['sugar']);
    return value['approximation_version'] == 'sugar-cubes-4g-v1' &&
            _number(value['sugars_g']) != null &&
            _number(value['cubes']) != null
        ? SugarView.fromJson(value)
        : null;
  }

  List<ReportClaimView> get claims =>
      _list(raw['claims'])
          .map((item) => ReportClaimView.fromJson(_map(item)))
          .toList(growable: false);
  List<IngredientInsight> get ingredientInsights {
    final seen = <String>{};
    return _list(raw['ingredient_insights'])
        .map((item) => IngredientInsight.fromJson(_map(item)))
        .where((item) => seen.add(item.name))
        .toList(growable: false);
  }

  List<ReportNutrient> get nutrients {
    if (isHistorical) {
      return _list(raw['resolved_nutrients'])
          .map((item) {
            final field = _map(item);
            final state = _text(field['state']) ?? 'unknown';
            return ReportNutrient(
              name: (_text(field['field']) ?? 'unknown').split('.').last,
              value: const ['single_source', 'agreement'].contains(state)
                  ? _number(field['value'])
                  : null,
              unit: _text(field['unit']) ?? 'g',
              basisLabel: basisDescription(
                field['basis'],
                field['preparation'],
              ),
              state: state,
              sourceIds: List.unmodifiable(_strings(field['source_ids'])),
              evidenceState: _text(field['evidence_state']),
              observedOn: _text(field['observed_on']),
              sourceUpdatedAt: _text(field['source_updated_at']),
            );
          })
          .toList(growable: false);
    }
    final result = <ReportNutrient>[];
    for (final item in _list(_map(raw['nutrition'])['tables'])) {
      final table = _map(item);
      for (final entry in _map(table['nutrients']).entries) {
        final cell = _map(entry.value);
        result.add(
          ReportNutrient(
            name: entry.key,
            value: _number(cell['value']),
            unit: _text(cell['unit']) ?? 'g',
            basisLabel: basisDescription(
              table['normalized_basis'],
              table['preparation'],
            ),
            state: _text(cell['reason']) ?? 'confirmed',
            sourceIds: const ['confirmed-label'],
            evidenceState: 'user_confirmed_label',
            observedOn: _text(_map(raw['observation'])['observed_on']),
          ),
        );
      }
    }
    return result;
  }

  List<String> get sourceLabels {
    if (!isHistorical) {
      return [
        'Your independently transcribed package · ${_map(raw['observation'])['observed_on'] ?? 'date unknown'}',
        'Submitter confirmed; automatic storage does not certify the facts.',
      ];
    }
    final resolved = _map(raw['resolved']);
    final snapshot = _map(resolved['off_snapshot']);
    final manifest = _map(snapshot['manifest']);
    final labels = <String>[];
    if (snapshot['status'] == 'found') {
      labels.add(
        'Open Food Facts · snapshot ${manifest['exported_at'] ?? 'date unknown'} · ODbL / DbCL',
      );
    }
    for (final item in _list(_map(resolved['community'])['revisions'])) {
      final revision = _map(item);
      labels.add(
        'Community package observation · ${_map(revision['facts'])['observed_on'] ?? 'date unknown'} · ${revision['review_state'] == 'submitter_confirmed_not_moderator_reviewed' ? 'submitter confirmed, unreviewed' : 'community assertion'} · CC0',
      );
    }
    return labels.isEmpty ? ['Source information unavailable'] : labels;
  }
}

class SearchCandidate {
  SearchCandidate.fromJson(JsonMap value) {
    final identity = _map(value['identity']);
    barcode = _text(identity['barcode']) ?? '';
    name = _text(identity['name']) ?? 'Product name unavailable';
    brand = _text(identity['brands']);
    quantity = _text(identity['quantity_text']);
    sourceId = _text(value['source_id']) ?? '';
    if (!RegExp(r'^(?:[0-9]{8}|[0-9]{12,14})$').hasMatch(barcode) ||
        sourceId.isEmpty ||
        (identity['name'] != null && identity['name'] is! String) ||
        (identity['brands'] != null && identity['brands'] is! String) ||
        (identity['quantity_text'] != null &&
            identity['quantity_text'] is! String)) {
      throw const AppFailure(
        'invalid_response',
        'The service returned an unreadable search result. Please try again.',
      );
    }
  }
  late final String barcode;
  late final String name;
  late final String? brand;
  late final String? quantity;
  late final String sourceId;
  String? get imageUrl => null;
}

class SearchPage {
  SearchPage.fromJson(JsonMap value)
    : status = _text(value['status']) ?? '',
      normalizedQuery = _text(value['normalized_query']) ?? '',
      candidates = List.unmodifiable(
        _list(value['candidates'])
            .map((item) => SearchCandidate.fromJson(_map(item))),
      ),
      nextCursor = _text(value['next_cursor']),
      matchedCount = value['matched_count'] is int
          ? value['matched_count'] as int
          : null,
      ambiguous = value['ambiguous'] is bool
          ? value['ambiguous'] as bool
          : null,
      warnings = List.unmodifiable(_strings(value['warnings'])) {
    if (value['schema_version'] != '1' ||
        value['search_version'] != 'catalogue-search-v1' ||
        !const [
          'ready',
          'not_found',
          'refine_query',
          'unavailable',
        ].contains(status) ||
        candidates.length > 20) {
      throw const AppFailure(
        'invalid_response',
        'The service returned an unreadable search result. Please try again.',
      );
    }
    _require(
      value['candidates'] is List && _stringList(value['warnings'], 100),
    );
    _require(_validText(value['normalized_query'], 519));
    _require(
      value['next_cursor'] == null || _validText(value['next_cursor'], 256),
    );
    _require(
      value['matched_count'] == null ||
          (value['matched_count'] is int &&
              (value['matched_count'] as int) >= 0 &&
              (value['matched_count'] as int) <= 1000),
    );
    _require(value['ambiguous'] == null || value['ambiguous'] is bool);
  }
  final String status;
  final String normalizedQuery;
  final List<SearchCandidate> candidates;
  final String? nextCursor;
  final int? matchedCount;
  final bool? ambiguous;
  final List<String> warnings;
}
