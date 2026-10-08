import 'dart:collection';
import 'dart:convert';

import 'app_failure.dart';
import 'product_report.dart' show JsonMap;

const _invalid = AppFailure(
  'invalid_response',
  'The service returned product information we could not read. Please try again.',
);
final _hash = RegExp(r'^[0-9a-f]{64}$');
final _barcode = RegExp(r'^(?:[0-9]{8}|[0-9]{12,14})$');
const _matches = ['exact_sku', 'identity_unconfirmed', 'brand_family_only'];
const _qualifiers = [
  'exact',
  'less_than',
  'less_than_or_equal',
  'greater_than',
  'greater_than_or_equal',
  'approximate',
  'unknown',
];

JsonMap _map(Object? value) {
  if (value is! JsonMap) throw _invalid;
  return value;
}

String? _text(Object? value, int limit, {bool required = false}) {
  if (value == null && !required) return null;
  if (value is! String || value.trim().isEmpty || value.length > limit) {
    throw _invalid;
  }
  return value;
}

List<dynamic> _list(Object? value, int limit) {
  if (value is! List || value.length > limit) throw _invalid;
  return value;
}

String researchProviderLabel(String value) => switch (value) {
  'manufacturer' => 'Manufacturer website',
  'retailer' => 'Retailer listing',
  'open_food_facts' => 'Open Food Facts',
  _ => 'Source unavailable',
};
String _provider(Object? value) {
  if (!const ['manufacturer', 'retailer', 'open_food_facts'].contains(value)) {
    throw _invalid;
  }
  return value as String;
}

String _sourceUrl(Object? value) {
  final text = _text(value, 2048, required: true)!;
  final uri = Uri.tryParse(text);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      (uri.hasPort && uri.port != 443) ||
      text.codeUnits.any((unit) => unit > 127 || unit <= 32) ||
      uri.queryParameters.keys.any(
        (key) => RegExp(
          r'token|password|secret|api.?key|authorization',
          caseSensitive: false,
        ).hasMatch(key),
      )) {
    throw _invalid;
  }
  return text;
}

String _date(Object? value) {
  final text = _text(value, 64, required: true)!;
  if (!RegExp(
        r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$',
      ).hasMatch(text) ||
      DateTime.tryParse(text) == null) {
    throw _invalid;
  }
  final year = int.parse(text.substring(0, 4));
  final month = int.parse(text.substring(5, 7));
  final day = int.parse(text.substring(8, 10));
  final calendar = DateTime.utc(year, month, day);
  if (calendar.year != year ||
      calendar.month != month ||
      calendar.day != day ||
      int.parse(text.substring(11, 13)) > 23 ||
      int.parse(text.substring(14, 16)) > 59 ||
      int.parse(text.substring(17, 19)) > 59) {
    throw _invalid;
  }
  return text;
}

void _identity(JsonMap identity) {
  final code = _text(identity['barcode'], 14);
  if (code != null && !_barcode.hasMatch(code)) throw _invalid;
  if (!_matches.contains(identity['match']) ||
      !const ['india', 'unknown'].contains(identity['market'])) {
    throw _invalid;
  }
  final evidence = identity['barcode_evidence_url'];
  if (evidence != null) _sourceUrl(evidence);
  if (identity['match'] == 'exact_sku' &&
      (code == null ||
          evidence == null ||
          identity['market'] != 'india' ||
          identity['name'] == null ||
          identity['brand'] == null ||
          identity['quantity'] == null)) {
    throw _invalid;
  }
}

Object? _freeze(Object? value, [int depth = 0]) {
  if (depth > 16) throw _invalid;
  if (value is Map) {
    if (value.length > 200 ||
        value.keys.any(
          (key) => key is! String || key.isEmpty || key.length > 128,
        )) {
      throw _invalid;
    }
    return UnmodifiableMapView<String, dynamic>(
      value.map<String, dynamic>(
        (key, item) => MapEntry(key as String, _freeze(item, depth + 1)),
      ),
    );
  }
  if (value is List) {
    if (value.length > 200) throw _invalid;
    return List<dynamic>.unmodifiable(
      value.map((item) => _freeze(item, depth + 1)),
    );
  }
  if (value is String && value.length > 16000) throw _invalid;
  if (value is num && (!value.isFinite || value.abs() > 1000000000000)) {
    throw _invalid;
  }
  if (value != null && value is! String && value is! num && value is! bool) {
    throw _invalid;
  }
  return value;
}

class ResearchSourceInfo {
  ResearchSourceInfo.fromJson(JsonMap value) {
    provider = _provider(value['provider']);
    url = _sourceUrl(value['url']);
    retrievedAt = _date(value['retrieved_at']);
    final updated = value['source_updated_at'];
    sourceUpdatedAt = updated == null ? null : _date(updated);
    if (sourceUpdatedAt != null &&
        DateTime.parse(sourceUpdatedAt!).isAfter(DateTime.parse(retrievedAt))) {
      throw _invalid;
    }
    final license = _map(value['license']);
    _text(license['reuse_status'], 128, required: true);
    for (final key in ['database', 'contents', 'images', 'note']) {
      _text(license[key], 2000);
    }
  }
  late final String provider, url, retrievedAt;
  late final String? sourceUpdatedAt;
}

class ResearchedCandidate {
  ResearchedCandidate.fromJson(JsonMap value) {
    entryId = _text(value['entry_id'], 64, required: true)!;
    if (!_hash.hasMatch(entryId)) throw _invalid;
    final identity = _map(value['identity']);
    _identity(identity);
    name = _text(identity['name'], 2000) ?? 'Product name unavailable';
    brand = _text(identity['brand'], 256);
    variant = _text(identity['variant'], 256);
    quantity = _text(identity['quantity'], 256);
    barcode = _text(identity['barcode'], 14);
    provider = _provider(value['provider']);
    source = ResearchSourceInfo.fromJson(_map(value['source']));
    if (source.provider != provider) throw _invalid;
    eligibility = _text(value['eligibility'], 64, required: true)!;
    if (!const [..._matches, 'conflicting'].contains(eligibility) ||
        (eligibility != 'conflicting' && eligibility != identity['match'])) {
      throw _invalid;
    }
  }
  late final String entryId, name, provider, eligibility;
  late final String? brand, variant, quantity, barcode;
  late final ResearchSourceInfo source;
}

class ResearchSearchPage {
  ResearchSearchPage.empty()
    : status = 'unavailable',
      candidates = const [],
      nextCursor = null,
      matchedCount = null;
  ResearchSearchPage.fromJson(JsonMap value) {
    if (value['schema_version'] != '1' ||
        value['search_version'] != 'research-search-v1') {
      throw _invalid;
    }
    status = _text(value['status'], 32, required: true)!;
    if (!const [
      'ready',
      'not_found',
      'unavailable',
      'refine_query',
    ].contains(status)) {
      throw _invalid;
    }
    candidates = List.unmodifiable(
      _list(
        value['candidates'],
        20,
      ).map((item) => ResearchedCandidate.fromJson(_map(item))),
    );
    nextCursor = _text(value['next_cursor'], 256);
    final count = value['matched_count'];
    if (count != null &&
        (count is! int ||
            count < 0 ||
            count > 1000 ||
            count < candidates.length)) {
      throw _invalid;
    }
    matchedCount = count as int?;
    if (candidates.map((item) => item.entryId).toSet().length !=
            candidates.length ||
        (status != 'ready' && (candidates.isNotEmpty || nextCursor != null))) {
      throw _invalid;
    }
  }
  late final String status;
  late final List<ResearchedCandidate> candidates;
  late final String? nextCursor;
  late final int? matchedCount;
}

class ResearchedProduct {
  ResearchedProduct.fromJson(JsonMap value) {
    if (value['schema_version'] != '1' || value['status'] != 'found') {
      throw _invalid;
    }
    entryId = _text(value['entry_id'], 64, required: true)!;
    if (!_hash.hasMatch(entryId)) throw _invalid;
    final record = _map(value['observation']);
    if (record['schema_version'] != 'popular-india-research-v1' ||
        record['observation_id'] != entryId) {
      throw _invalid;
    }
    try {
      if (utf8.encode(jsonEncode(record)).length > 256 * 1024) throw _invalid;
    } on JsonUnsupportedObjectError {
      throw _invalid;
    }
    final identity = _map(record['identity']);
    _identity(identity);
    name = _text(identity['name'], 2000) ?? 'Product name unavailable';
    brand = _text(identity['brand'], 256);
    variant = _text(identity['variant'], 256);
    quantity = _text(identity['quantity'], 256);
    barcode = _text(identity['barcode'], 14);
    match = identity['match'] as String;
    if (record['eligibility'] != match) throw _invalid;
    final source = ResearchSourceInfo.fromJson(_map(record['source']));
    provider = source.provider;
    sourceUrl = source.url;
    retrievedAt = source.retrievedAt;
    sourceUpdatedAt = source.sourceUpdatedAt;
    final picture = value['image'];
    if (picture != null) {
      final descriptor = _map(picture);
      if (descriptor['observation_id'] != entryId ||
          descriptor['source_url'] != sourceUrl ||
          descriptor['provider'] != provider ||
          !const [
            'source_listing',
            'source_barcode',
          ].contains(descriptor['identity_scope']) ||
          !const [
            'image/jpeg',
            'image/png',
            'image/webp',
          ].contains(descriptor['content_type'])) {
        throw _invalid;
      }
      const origins = {
        'world.openfoodfacts.org': ['images.openfoodfacts.org'],
        'blinkit.com': ['cdn.grofers.com'],
        'business.bigbasket.com': ['www.bbassets.com'],
        'bbnow.bigbasket.com': ['www.bbassets.com'],
        'www.bigbasket.com': ['www.bbassets.com'],
        'www.balajiwafers.com': ['www.balajiwafers.com'],
        'www.bikaji.com': ['www.bikaji.com'],
        'www.coca-cola.com': ['www.coca-cola.com'],
        'instamart.in': ['instamart-media-assets.swiggy.com'],
        'www.aamghar.in': ['www.aamghar.in'],
      };
      imageUrl = _sourceUrl(descriptor['url']);
      if (!(origins[Uri.parse(sourceUrl).host] ?? []).contains(
        Uri.parse(imageUrl!).host,
      )) {
        throw _invalid;
      }
      if (provider == 'open_food_facts') {
        final sourceCode = RegExp(
          r'/product/([0-9]{8}|[0-9]{12,14})(?:\.json|/|$)',
        ).firstMatch(Uri.parse(sourceUrl).path)?.group(1);
        if (sourceCode == null ||
            sourceCode != barcode ||
            descriptor['identity_scope'] != 'source_barcode' ||
            descriptor['method'] != 'off_selected_front' ||
            descriptor['content_type'] != 'image/jpeg') {
          throw _invalid;
        }
        final significant = sourceCode.replaceFirst(RegExp(r'^0+'), '');
        if (significant.length < 4) throw _invalid;
        final digits = significant.padLeft(13, '0');
        final folder =
            '${digits.substring(0, 3)}/${digits.substring(3, 6)}/${digits.substring(6, 9)}/${digits.substring(9)}';
        if (!RegExp(
          '^https://images\\.openfoodfacts\\.org/images/products/$folder/front_[a-z]{2,3}\\.[1-9][0-9]{0,9}\\.400\\.jpg\$',
        ).hasMatch(imageUrl!)) {
          throw _invalid;
        }
      } else if (descriptor['identity_scope'] != 'source_listing' ||
          !const [
            'structured_product',
            'opengraph_product',
            'retailer_product_id',
          ].contains(descriptor['method'])) {
        throw _invalid;
      }
      if (!_hash.hasMatch(
        _text(descriptor['evidence_sha256'], 64, required: true)!,
      )) {
        throw _invalid;
      }
      imageAttribution = _text(descriptor['attribution'], 256, required: true);
      imageLicense = _text(descriptor['license'], 256, required: true);
      _date(descriptor['retrieved_at']);
    }
    final sections = _map(record['sections']);
    for (final key in ['ingredients', 'contains', 'may_contain']) {
      if (sections[key] == null) continue;
      final section = _map(sections[key]);
      _text(section['text'], 16000, required: true);
      if (!const [
        'complete',
        'partial',
        'unknown',
      ].contains(section['completeness'])) {
        throw _invalid;
      }
      final provenance = ResearchSourceInfo.fromJson(
        _map(section['provenance']),
      );
      if (_sourceUrl(section['source_url']) != provenance.url ||
          provenance.provider != provider) {
        throw _invalid;
      }
    }
    final nutrition = _map(record['nutrition']);
    final tables = _list(nutrition['direct_tables'], 16);
    if (!const [
          'direct_reported',
          'legacy_aggregate_only',
          'missing',
        ].contains(nutrition['availability']) ||
        nutrition['legacy_present'] is! bool ||
        (tables.isNotEmpty && nutrition['availability'] != 'direct_reported') ||
        (tables.isEmpty && nutrition['availability'] == 'direct_reported')) {
      throw _invalid;
    }
    for (final table in tables) {
      final map = _map(table);
      final basis = _map(map['basis']);
      if (basis.keys.any(
        (key) => !const ['amount', 'unit', 'kind', 'description'].contains(key),
      )) {
        throw _invalid;
      }
      final amount = basis['amount'];
      if (amount != null &&
          (amount is! num ||
              !amount.isFinite ||
              amount <= 0 ||
              amount > 1000000 ||
              basis['unit'] == null)) {
        throw _invalid;
      }
      _text(basis['unit'], 64);
      _text(basis['kind'], 128);
      _text(basis['description'], 2000);
      if (!const [
        'as_sold',
        'as_prepared',
        'unknown',
      ].contains(map['preparation'])) {
        throw _invalid;
      }
      final provenance = ResearchSourceInfo.fromJson(_map(map['provenance']));
      final allowedSources = provider == 'open_food_facts'
          ? ['packaging', 'manufacturer']
          : provider == 'manufacturer'
          ? ['manufacturer']
          : ['retailer_transcription'];
      if (!allowedSources.contains(map['source']) ||
          provenance.provider != provider ||
          _sourceUrl(map['source_url']) != provenance.url ||
          _date(map['retrieved_at']) != provenance.retrievedAt ||
          map['source_updated_at'] != provenance.sourceUpdatedAt) {
        throw _invalid;
      }
      final rows = _list(map['rows'], 200);
      if (rows.isEmpty) throw _invalid;
      for (final row in rows) {
        final item = _map(row);
        _text(item['nutrient'], 128, required: true);
        _text(item['raw_label'], 2000);
        _text(item['unit'], 32);
        if (!_qualifiers.contains(item['qualifier'])) throw _invalid;
        final amount = item['value'];
        if (amount == null && item['qualifier'] != 'unknown') throw _invalid;
        if (amount != null &&
            (amount is! num ||
                !amount.isFinite ||
                amount < 0 ||
                amount > 1000000)) {
          throw _invalid;
        }
      }
    }
    conflictFields = List<String>.unmodifiable(
      _list(
        value['conflict_fields'] ?? [],
        16,
      ).map((item) => _text(item, 2000, required: true)!),
    );
    warnings = List<String>.unmodifiable(
      _list(
        value['warnings'] ?? [],
        100,
      ).map((item) => _text(item, 2000, required: true)!),
    );
    raw = _freeze(record) as JsonMap;
  }
  late final JsonMap raw;
  late final String entryId, name, match, provider, sourceUrl, retrievedAt;
  late final String? brand, variant, quantity, barcode, sourceUpdatedAt;
  String? imageUrl, imageAttribution, imageLicense;
  late final List<String> conflictFields, warnings;
  String? section(String key) => raw['sections'][key]?['text'] as String?;
  JsonMap? sectionInfo(String key) => raw['sections'][key] as JsonMap?;
  List<JsonMap> get tables => List<JsonMap>.unmodifiable(
    (raw['nutrition']['direct_tables'] as List).cast<JsonMap>(),
  );
  JsonMap get metadata =>
      raw['metadata'] is JsonMap ? raw['metadata'] as JsonMap : const {};
}
