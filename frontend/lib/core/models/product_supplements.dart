import 'app_failure.dart';
import 'extracted_label.dart';
import 'product_report.dart' show JsonMap;

const _invalid = AppFailure(
  'invalid_response',
  'Additional product facts could not be read reliably.',
);
void _check(bool value) {
  if (!value) throw _invalid;
}

String _text(Object? value, int max) {
  _check(value is String && value.trim().isNotEmpty && value.length <= max);
  return value as String;
}

List<String> _texts(Object? raw, int count, int length) {
  _check(raw is List && raw.length <= count);
  return List.unmodifiable((raw as List).map((v) => _text(v, length)));
}

/// Session-only vendor data; deliberately has no serialization/save method.
class LiveProduct {
  LiveProduct._(
    this.name,
    this.brand,
    this.fields,
    this.sources,
    this.expiresAt,
  );
  factory LiveProduct.fromJson(JsonMap raw, String barcode, DateTime now) {
    _check(
      raw['barcode'] == barcode &&
          raw['evidence'] == 'external_provider_unverified' &&
          raw['attribution'] == 'Data by NutriGraphAPI' &&
          raw['attribution_url'] == 'https://nutrigraphapi.com',
    );
    final fetched = DateTime.tryParse(_text(raw['retrieved_at'], 64));
    final expires = DateTime.tryParse(_text(raw['expires_at'], 64));
    _check(
      fetched != null &&
          expires != null &&
          fetched.isUtc &&
          expires.isUtc &&
          expires.isAfter(fetched) &&
          expires.difference(fetched) <= const Duration(hours: 24) &&
          fetched.isBefore(now.add(const Duration(minutes: 5))),
    );
    final fields = raw['fields'];
    _check(fields is List && fields.length <= 256);
    return LiveProduct._(
      raw['name'] == null ? null : _text(raw['name'], 512),
      raw['brand'] == null ? null : _text(raw['brand'], 512),
      List.unmodifiable(
        (fields as List).map((v) {
          _check(v is JsonMap);
          return LiveProductField.fromJson(v as JsonMap);
        }),
      ),
      _texts(raw['sources'], 128, 4096),
      expires!,
    );
  }
  final String? name, brand;
  final List<LiveProductField> fields;
  final List<String> sources;
  final DateTime expiresAt;
}

class LiveProductField {
  LiveProductField._(this.section, this.label, this.value, this.sources);
  factory LiveProductField.fromJson(JsonMap raw) {
    _check(
      const ['ingredients', 'allergens', 'nutrition'].contains(raw['section']),
    );
    return LiveProductField._(
      raw['section'],
      _text(raw['label'], 1024),
      _text(raw['value'], 16000),
      _texts(raw['sources'], 128, 4096),
    );
  }
  final String section, label, value;
  final List<String> sources;
}

class LiveProductLookup {
  const LiveProductLookup(this.status, [this.product]);
  factory LiveProductLookup.fromJson(
    JsonMap raw,
    String barcode,
    DateTime now,
  ) {
    _check(
      raw['requested_barcode'] == barcode &&
          const [
            'found',
            'disabled',
            'unsupported_barcode',
            'not_found',
            'rate_limited',
            'unavailable',
          ].contains(raw['status']),
    );
    _check(
      raw['status'] == 'found'
          ? raw['product'] is JsonMap
          : raw['product'] == null,
    );
    final product = raw['product'] == null
        ? null
        : LiveProduct.fromJson(raw['product'] as JsonMap, barcode, now);
    if (product != null && !now.isBefore(product.expiresAt)) {
      return const LiveProductLookup('unavailable');
    }
    return LiveProductLookup(raw['status'], product);
  }
  final String status;
  final LiveProduct? product;
}

class MachineProductReading {
  MachineProductReading._(this.label, this.date, this.provider, this.conflicts);
  factory MachineProductReading.fromJson(JsonMap raw, String barcode) {
    _check(
      raw['schema_version'] == 'machine-label-observation-v1' &&
          raw['evidence'] == 'machine_extracted_unverified' &&
          raw['barcode'] == barcode &&
          raw['contribution_policy'] == 'machine-unverified-v1' &&
          raw['facts'] is JsonMap &&
          const ['gemini', 'openai'].contains(raw['provider']),
    );
    final date = DateTime.tryParse(_text(raw['observed_at'], 64));
    _check(date != null && date.isUtc);
    final label = ExtractedLabel.fromJson({
      ...raw['facts'] as JsonMap,
      'schema_version': '1',
      'evidence': 'machine_extracted_unverified',
      'regions': <Object>[],
    });
    _check(
      label.identity['barcode'] == null || label.identity['barcode'] == barcode,
    );
    return MachineProductReading._(
      label,
      date!,
      raw['provider'],
      _texts(raw['conflict_fields'], 128, 256),
    );
  }
  final ExtractedLabel label;
  final DateTime date;
  final String provider;
  final List<String> conflicts;
}

class MachineProductLookup {
  const MachineProductLookup(this.readings, this.conflicts);
  factory MachineProductLookup.fromJson(JsonMap raw, String barcode) {
    _check(
      raw['schema_version'] == 'machine-label-lookup-v1' &&
          raw['barcode'] == barcode &&
          raw['evidence'] == 'machine_extracted_unverified' &&
          const ['found', 'not_found'].contains(raw['status']),
    );
    final items = raw['observations'];
    _check(items is List && items.length <= 8);
    return MachineProductLookup(
      List.unmodifiable(
        (items as List).map((v) {
          _check(v is JsonMap);
          return MachineProductReading.fromJson(v as JsonMap, barcode);
        }),
      ),
      _texts(raw['conflict_fields'], 128, 256),
    );
  }
  final List<MachineProductReading> readings;
  final List<String> conflicts;
}

/// A read-only check of photographed claim text against dated catalogue facts.
/// This object is never folded into a saved, confirmed package report.
class CatalogueClaimCheck {
  CatalogueClaimCheck._(this.status, this.assessments, this.sourceIds);
  factory CatalogueClaimCheck.fromJson(
    JsonMap raw,
    String barcode,
    List<String> claims,
  ) {
    _check(
      raw['schema_version'] == 'catalogue-claim-check-v1' &&
          raw['barcode'] == barcode &&
          raw['assessment_basis'] == 'catalogue_historical' &&
          const ['ready', 'unavailable', 'not_found'].contains(raw['status']),
    );
    final items = raw['assessments'];
    _check(items is List && items.length <= 16);
    final assessments = (items as List)
        .map((item) {
          _check(item is JsonMap);
          final row = item as JsonMap;
          _check(
            claims.contains(row['text']) &&
                row['status'] == 'insufficient_information',
          );
          _texts(row['reasons'], 128, 512);
          _texts(row['rule_source_ids'], 128, 256);
          final comparisons = row['comparisons'];
          _check(comparisons is List && comparisons.length <= 256);
          for (final value in comparisons as List) {
            _check(value is JsonMap);
            final comparison = value as JsonMap;
            for (final key in [
              'source_id',
              'table_id',
              'criterion_id',
              'basis',
              'nutrient',
              'operator',
              'unit',
            ]) {
              _text(comparison[key], 512);
            }
            _check(
              const [
                'pass',
                'fail',
                'unknown',
                'not_applicable',
              ].contains(comparison['outcome']),
            );
            for (final key in ['value', 'threshold']) {
              final number = comparison[key];
              _check(
                (key == 'value' && number == null) ||
                    number is num && number.isFinite && number >= 0,
              );
            }
          }
          return Map<String, dynamic>.unmodifiable(row);
        })
        .toList(growable: false);
    _check(
      assessments.map((row) => row['text']).toSet().length ==
          assessments.length,
    );
    return CatalogueClaimCheck._(
      raw['status'],
      List.unmodifiable(assessments),
      _texts(raw['source_ids'], 128, 512),
    );
  }
  final String status;
  final List<JsonMap> assessments;
  final List<String> sourceIds;
}
