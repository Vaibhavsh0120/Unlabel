import 'dart:collection';
import 'dart:convert';

import 'app_failure.dart';
import 'label_draft.dart';
import 'product_report.dart';

const comparisonVersion = 'sourced-nutrient-comparison-v1';
JsonMap _map(Object? value) => value is JsonMap ? value : {};
List<dynamic> _list(Object? value) => value is List ? value : const [];
void _require(bool valid) {
  if (!valid) {
    throw const AppFailure(
      'invalid_response',
      'The sourced comparison could not be read. Please try again.',
    );
  }
}

bool _text(Object? value, [int max = 2000]) =>
    value is String && value.isNotEmpty && value.length <= max;
bool _number(Object? value, [double max = 1e9]) =>
    value is num && value.isFinite && value >= 0 && value <= max;
bool _hash(Object? value) =>
    value is String && RegExp(r'^[0-9a-f]{64}$').hasMatch(value);
bool _uuid(Object? value) =>
    value is String &&
    RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
bool _tableId(Object? value) =>
    value is String &&
    RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,63}$').hasMatch(value);
bool _barcode(Object? value) =>
    value is String && RegExp(r'^(?:[0-9]{8}|[0-9]{12,14})$').hasMatch(value);
bool _strings(Object? value, [int max = 100]) =>
    value is List &&
    value.length <= max &&
    value.every((item) => _text(item, 2000));
JsonMap _freeze(JsonMap value) => UnmodifiableMapView(
  value.map(
    (key, item) => MapEntry(
      key,
      item is JsonMap
          ? _freeze(item)
          : item is List
          ? _freezeList(item)
          : item,
    ),
  ),
);
List<dynamic> _freezeList(List value) => List.unmodifiable(
  value.map(
    (item) => item is JsonMap
        ? _freeze(item)
        : item is List
        ? _freezeList(item)
        : item,
  ),
);
bool _same(Object? a, Object? b) => a is Map && b is Map
    ? a.length == b.length &&
          a.keys.every((key) => b.containsKey(key) && _same(a[key], b[key]))
    : a is List && b is List
    ? a.length == b.length &&
          List.generate(a.length, (i) => i).every((i) => _same(a[i], b[i]))
    : a == b;

/// One actual source and table, never a synthetic merge of resolved fields.
class ComparisonOption {
  ComparisonOption.fromInput(
    JsonMap input, {
    required this.label,
    required JsonMap basis,
    required this.preparation,
  }) : input = _freeze(input),
       basis = _freeze(basis) {
    _require(_tableId(input['selected_table_id']));
    switch (input['kind']) {
      case 'off_snapshot':
        _require(
          input.keys.toSet().difference({
                'kind',
                'barcode',
                'snapshot_id',
                'source_sha256',
                'selected_table_id',
              }).isEmpty &&
              _barcode(input['barcode']) &&
              _text(input['snapshot_id'], 128) &&
              _hash(input['source_sha256']),
        );
      case 'community_revision':
        _require(
          input.keys.toSet().difference({
                'kind',
                'barcode',
                'revision_id',
                'factual_sha256',
                'selected_table_id',
              }).isEmpty &&
              _barcode(input['barcode']) &&
              _hash(input['revision_id']) &&
              _hash(input['factual_sha256']),
        );
      case 'current_confirmed_label':
        final observation = _map(input['observation']);
        _require(
          input.keys.toSet().difference({
                'kind',
                'observation',
                'selected_table_id',
              }).isEmpty &&
              observation.keys.toSet().difference({
                'schema_version',
                'barcode',
                'identity',
                'ingredients',
                'contains',
                'may_contain',
                'front_claims',
                'rows',
                'nutrition_completeness',
                'nutrition_origin',
                'provider_references',
                'revision_context',
                'observed_on',
                'capture_method',
                'share_license',
                'market',
                'submission_id',
                'observation_state',
                'confirmed',
                'front_confirmed',
                'back_confirmed',
                'same_product_confirmed',
              }).isEmpty &&
              observation['observation_state'] == 'confirmed' &&
              observation['confirmed'] == true &&
              observation['front_confirmed'] == true &&
              observation['back_confirmed'] == true &&
              observation['same_product_confirmed'] == true &&
              _uuid(observation['submission_id']) &&
              const [
                'manual',
                'ocr_corrected',
              ].contains(observation['capture_method']),
        );
      default:
        _require(false);
    }
  }
  final JsonMap input, basis;
  final String label;
  final String? preparation;
  String get id =>
      '${input['kind']}:${input['snapshot_id'] ?? input['revision_id'] ?? _map(input['observation'])['submission_id']}:${input['selected_table_id']}';
  String get basisLabel => basisDescription(basis, preparation);
}

List<ComparisonOption> sourcedComparisonOptions(ProductReport report) {
  final result = <ComparisonOption>[];
  void add(JsonMap input, JsonMap table, String sourceLabel) {
    try {
      final basis = _map(table['original_basis']);
      final prep = table['preparation'];
      if (basis.isEmpty || prep is! String) return;
      result.add(
        ComparisonOption.fromInput(
          input,
          label: '$sourceLabel · ${basisDescription(basis, prep)}',
          basis: basis,
          preparation: prep,
        ),
      );
    } on AppFailure {
      /* A missing source pin cannot become comparison evidence. */
    }
  }

  if (!report.isHistorical) {
    final observation = report.confirmedComparisonObservation;
    if (observation == null) return result;
    final seen = <String>{};
    for (final item in _list(observation['rows'])) {
      final row = _map(item);
      final id = row['table_id'];
      if (id is! String || !seen.add(id)) continue;
      add(
        {
          'kind': 'current_confirmed_label',
          'observation': observation,
          'selected_table_id': id,
        },
        {'original_basis': row['basis'], 'preparation': row['preparation']},
        'Confirmed label · ${observation['observed_on']}',
      );
    }
    return result;
  }
  final resolved = _map(report.raw['resolved']);
  final off = _map(resolved['off_snapshot']);
  final manifest = _map(off['manifest']);
  final nutrition = _map(_map(off['details'])['nutrition']);
  if (off['status'] == 'found' &&
      nutrition['availability'] == 'direct_tables') {
    final sources = _list(nutrition['input_tables']);
    for (final item in _list(_map(nutrition['snapshot'])['tables'])) {
      final table = _map(item);
      final id = table['source_table_id'];
      final direct = sources.where(
        (source) =>
            _map(source)['table_id'] == id &&
            const [
              'packaging',
              'manufacturer',
            ].contains(_map(source)['provider_source']),
      );
      if (direct.length != 1) continue;
      add(
        {
          'kind': 'off_snapshot',
          'barcode': report.barcode,
          'snapshot_id': manifest['snapshot_id'],
          'source_sha256': manifest['source_sha256'],
          'selected_table_id': id,
        },
        table,
        'Open Food Facts · ${manifest['exported_at'] ?? 'date unknown'}',
      );
    }
  }
  for (final item in _list(_map(resolved['community'])['revisions'])) {
    final revision = _map(item);
    final revisionId = revision['revision_id'];
    if (revisionId is! String || !_hash(revisionId)) continue;
    for (final value in _list(_map(revision['snapshot'])['tables'])) {
      final table = _map(value);
      add(
        {
          'kind': 'community_revision',
          'barcode': report.barcode,
          'revision_id': revision['revision_id'],
          'factual_sha256': revision['factual_sha256'],
          'selected_table_id': table['source_table_id'],
        },
        table,
        'Community · ${_map(revision['facts'])['observed_on'] ?? 'date unknown'} · ${revisionId.substring(0, 8)}',
      );
    }
  }
  return result;
}

class SourcedCell {
  SourcedCell.fromJson(JsonMap raw, String nutrient)
    : value = raw['value'] is num ? (raw['value'] as num).toDouble() : null,
      unit = raw['unit'] as String? ?? '',
      reason = raw['reason'] as String?,
      rowIds = List.unmodifiable(_list(raw['source_row_ids']).cast<String>()) {
    _require(
      (raw['value'] == null || _number(raw['value'])) &&
          unit == (nutrient == 'energy' ? 'kcal' : 'g') &&
          (raw['reason'] == null || _text(raw['reason'])) &&
          _strings(raw['source_row_ids'], 64),
    );
    _require(value == null || (reason == null && rowIds.isNotEmpty));
  }
  final double? value;
  final String unit;
  final String? reason;
  final List<String> rowIds;
}

class SourcedRow {
  SourcedRow.fromJson(JsonMap raw)
    : name = raw['nutrient'] as String? ?? '',
      a = SourcedCell.fromJson(
        _map(raw['a']),
        raw['nutrient'] as String? ?? '',
      ),
      b = SourcedCell.fromJson(
        _map(raw['b']),
        raw['nutrient'] as String? ?? '',
      ),
      difference = raw['difference'] is num
          ? (raw['difference'] as num).toDouble()
          : null,
      reason = raw['reason'] as String?,
      lower = raw['lower'] as String? {
    _require(
      DraftNutrient.names.contains(name) &&
          (raw['difference'] == null ||
              (raw['difference'] is num &&
                  (raw['difference'] as num).isFinite &&
                  (raw['difference'] as num).abs() <= 1e9)) &&
          (reason == null || _text(reason)) &&
          (difference == null
              ? lower == null
              : const ['a', 'b', 'equal'].contains(lower)),
    );
    if (difference != null) {
      _require(a.value != null && b.value != null && reason == null);
      _require(
        (difference! - (b.value! - a.value!)).abs() <=
            1e-9 * (1 + difference!.abs() + a.value!.abs() + b.value!.abs()),
      );
      _require(
        lower ==
            (difference! > 0
                ? 'a'
                : difference! < 0
                ? 'b'
                : 'equal'),
      );
    }
  }
  final String name;
  final SourcedCell a, b;
  final double? difference;
  final String? lower, reason;
}

class SourcedSide {
  SourcedSide.fromJson(JsonMap raw) : raw = _freeze(raw) {
    _require(
      const [
            'ready',
            'needs_correction',
            'not_found',
            'source_changed',
            'unavailable',
          ].contains(raw['status']) &&
          const [
            'user_confirmed_label',
            'catalogue_historical',
          ].contains(raw['assessment_basis']) &&
          const [
            'current_confirmed_label',
            'off_snapshot',
            'community_revision',
          ].contains(raw['requested_kind']) &&
          _tableId(raw['selected_table_id']) &&
          _strings(raw['warnings']),
    );
    final source = _map(raw['source']);
    final table = _map(raw['selected_table']);
    if (raw['status'] == 'ready') {
      _require(
        source['kind'] == raw['requested_kind'] &&
            _text(source['source_id']) &&
            table['source_table_id'] == raw['selected_table_id'] &&
            _map(raw['snapshot']).isNotEmpty,
      );
      _require(const ['as_sold', 'as_prepared'].contains(table['preparation']));
      _require(
        source['qualification'] ==
            switch (source['kind']) {
              'current_confirmed_label' =>
                'user_confirmed_not_independently_verified',
              'off_snapshot' =>
                'historical_community_data_not_current_package_proof',
              'community_revision' =>
                'historical_assertion_not_current_package_proof',
              _ => null,
            },
      );
      if (source['kind'] == 'current_confirmed_label') {
        _require(
          _uuid(source['submission_id']) && _text(source['observed_on']),
        );
      } else if (source['kind'] == 'off_snapshot') {
        _require(
          _hash(_map(source['manifest'])['source_sha256']) &&
              _text(_map(source['manifest'])['snapshot_id']),
        );
      } else {
        _require(
          _hash(source['revision_id']) &&
              _hash(source['factual_sha256']) &&
              _text(source['observed_on']),
        );
      }
    }
    _require(originalRows.length <= 64);
    for (final item in originalRows) {
      final row = _map(item);
      _require(
        _tableId(row['row_id']) &&
            _tableId(row['table_id']) &&
            DraftNutrient.names.contains(row['nutrient']) &&
            (row['value'] == null || _number(row['value'], 1e6)) &&
            const ['g', 'mg', 'ug', 'kcal', 'kJ'].contains(row['unit']) &&
            _map(row['basis']).isNotEmpty,
      );
    }
  }
  final JsonMap raw;
  String get status => raw['status'] as String;
  String get tableId => raw['selected_table_id'] as String;
  List<dynamic> get originalRows =>
      _list(_map(raw['snapshot'])['original_rows'])
          .where((item) => _map(item)['table_id'] == tableId)
          .toList();
  String get sourceLabel {
    final source = _map(raw['source']);
    if (source.isEmpty) return comparisonReason(status);
    return switch (source['kind']) {
      'current_confirmed_label' =>
        'Your confirmed label · ${source['observed_on']} · not independently verified',
      'off_snapshot' =>
        'Open Food Facts · snapshot ${_map(source['manifest'])['exported_at']} · dated community data · ODbL / DbCL',
      'community_revision' =>
        'Community observation · ${source['observed_on']} · ${source['review_state'] == 'submitter_confirmed_not_moderator_reviewed' ? 'submitter confirmed, unreviewed' : 'reviewed community assertion'} · CC0',
      _ => 'Source information unavailable',
    };
  }
}

class SourcedComparison {
  factory SourcedComparison.fromJson(JsonMap raw) {
    try {
      return SourcedComparison._(raw);
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
        'invalid_response',
        'The sourced comparison could not be read. Please try again.',
      );
    }
  }
  SourcedComparison._(JsonMap raw)
    : raw = _freeze(raw),
      a = SourcedSide.fromJson(_map(raw['a'])),
      b = SourcedSide.fromJson(_map(raw['b'])),
      rows = List.unmodifiable(
        _list(raw['nutrients']).map((item) => SourcedRow.fromJson(_map(item))),
      ) {
    _require(
      raw['schema_version'] == '1' &&
          raw['comparison_version'] == comparisonVersion &&
          raw['normalization_version'] == '1' &&
          raw['energy_conversion'] == 'nutrition-comparison-4.184-v1' &&
          raw['difference_definition'] == 'b_minus_a' &&
          raw['storage'] == 'read_only' &&
          _uuid(raw['client_request_id']) &&
          _uuid(raw['comparison_session_id']) &&
          raw['input_revision'] is int &&
          (raw['input_revision'] as int) >= 0 &&
          (raw['input_revision'] as int) <= 2147483647 &&
          DateTime.tryParse(raw['generated_at'] as String? ?? '') != null &&
          const ['ready', 'partial', 'not_comparable'].contains(status) &&
          _strings(raw['warnings']),
    );
    _require(
      rows.length == 11 &&
          List.generate(
            11,
            (i) => i,
          ).every((i) => rows[i].name == DraftNutrient.names[i]),
    );
    if (status == 'not_comparable') {
      _require(rows.every((row) => row.difference == null));
    } else {
      final basis = _map(raw['comparison_basis']);
      _require(
        a.status == 'ready' &&
            b.status == 'ready' &&
            basis['kind'] == 'quantity' &&
            basis['amount'] == 100 &&
            const ['g', 'mL'].contains(basis['unit']) &&
            const ['as_sold', 'as_prepared'].contains(raw['preparation']),
      );
    }
    if (status == 'ready') {
      _require(rows.every((row) => row.difference != null));
    }
  }
  final JsonMap raw;
  final SourcedSide a, b;
  final List<SourcedRow> rows;
  String get status => raw['status'] as String;
  String get basisLabel =>
      basisDescription(raw['comparison_basis'], raw['preparation']);
  void requireRequest(
    ComparisonOption left,
    ComparisonOption right,
    String requestId,
    String sessionId,
    int revision,
  ) {
    _require(
      raw['client_request_id'] == requestId &&
          raw['comparison_session_id'] == sessionId &&
          raw['input_revision'] == revision,
    );
    for (final pair in [(a, left), (b, right)]) {
      final side = pair.$1;
      final input = pair.$2.input;
      _require(
        side.tableId == input['selected_table_id'] &&
            side.raw['requested_kind'] == input['kind'],
      );
      if (input['kind'] == 'current_confirmed_label') {
        _require(
          side.raw['requested_reference'] == null &&
              _map(side.raw['source'])['submission_id'] ==
                  _map(input['observation'])['submission_id'],
        );
      } else {
        _require(_same(side.raw['requested_reference'], input));
        final source = _map(side.raw['source']);
        if (source.isNotEmpty && input['kind'] == 'off_snapshot') {
          final manifest = _map(source['manifest']);
          _require(
            manifest['snapshot_id'] == input['snapshot_id'] &&
                manifest['source_sha256'] == input['source_sha256'],
          );
        } else if (source.isNotEmpty && input['kind'] == 'community_revision') {
          _require(
            source['revision_id'] == input['revision_id'] &&
                source['factual_sha256'] == input['factual_sha256'],
          );
        }
      }
    }
  }
}

String comparisonReason(String? reason) => switch (reason) {
  'source_changed' || 'source_reference_changed' =>
    'This source changed. Look up the product again.',
  'not_found' || 'source_not_found' || 'active_public_revision_not_found' =>
    'The exact dated source is no longer available. Look up the product again.',
  'preparation_mismatch' => 'The products use different preparation methods.',
  'mass_volume_mismatch' =>
    'Grams and millilitres cannot be compared without density.',
  'measured_quantity_basis_required' => 'A printed serving amount is needed.',
  'unknown_value' ||
  'not_reported' ||
  'nutrient_unknown' => 'More label information needed',
  'conflicting_values' ||
  'conflicting_nutrient_values' => 'Conflicting facts need correction',
  'source_needs_attention' || 'source_needs_correction' || 'needs_correction' =>
    'A source needs correction before amounts can be compared.',
  'conversion_out_of_bounds' => 'This amount cannot be converted safely.',
  'unavailable' ||
  'source_unavailable' => 'This exact source is temporarily unavailable.',
  null => 'More label information needed',
  _ => reason.replaceAll('_', ' '),
};

int comparisonRequestBytes(JsonMap request) =>
    utf8.encode(jsonEncode(request)).length;
