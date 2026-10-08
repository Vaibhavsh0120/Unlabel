import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/app_failure.dart';
import '../models/label_draft.dart';
import '../models/product_report.dart';
import '../models/sourced_comparison.dart';
import '../models/researched_product.dart';
import '../models/extracted_label.dart';
import 'scanner_auth.dart';

export '../models/app_failure.dart';
export '../models/label_draft.dart';
export '../models/product_report.dart';
export '../models/sourced_comparison.dart';
export '../models/researched_product.dart';
export '../models/extracted_label.dart';

class UnlabelRepository {
  UnlabelRepository({
    required String baseUrl,
    http.Client? client,
    ScannerAuth auth = const UnavailableScannerAuth(),
    this.timeout = const Duration(seconds: 15),
    this.authTimeout = const Duration(seconds: 8),
    this.maxResponseBytes = 2 * 1024 * 1024,
    DateTime Function()? clock,
    bool allowLocalHttp = kDebugMode,
  }) : _client = client ?? http.Client(),
       // ignore: prefer_initializing_formals
       _auth = auth,
       _clock = clock ?? DateTime.now,
       _base = _validateBase(baseUrl, allowLocalHttp);
  final http.Client _client;
  final ScannerAuth _auth;
  final Uri _base;
  final DateTime Function() _clock;
  final Duration timeout;
  final Duration authTimeout;
  final int maxResponseBytes;
  JsonMap? _metadata;
  DateTime? _metadataAt;
  Future<JsonMap>? _metadataPending;
  bool _closed = false;
  late final _searchCache = _PublicReadCache<SearchPage>(
    ttl: const Duration(seconds: 60),
    maxEntries: 20,
    clock: _clock,
  );
  late final _reportCache = _PublicReadCache<ProductReport>(
    ttl: const Duration(minutes: 5),
    maxEntries: 40,
    clock: _clock,
  );
  late final _researchSearchCache = _PublicReadCache<ResearchSearchPage>(
    ttl: const Duration(seconds: 60),
    maxEntries: 20,
    clock: _clock,
  );
  late final _researchDetailCache = _PublicReadCache<ResearchedProduct>(
    ttl: const Duration(minutes: 5),
    maxEntries: 40,
    clock: _clock,
  );

  void _ensureOpen() {
    if (_closed) {
      throw const AppFailure('closed', 'This service connection has closed.');
    }
  }

  Future<JsonMap> _serviceMetadata() async {
    _ensureOpen();
    if (_metadataAt == null ||
        _clock().difference(_metadataAt!) >= const Duration(minutes: 5)) {
      _metadata = null;
    }
    final metadata =
        _metadata ??
        await (_metadataPending ??= _loadMetadata().whenComplete(
          () => _metadataPending = null,
        ));
    _ensureOpen();
    return metadata;
  }

  Future<void> _requireCapability(String capability) async {
    final metadata = await _serviceMetadata();
    final capabilities = metadata['capabilities'] as JsonMap;
    if (capabilities[capability] != true) {
      throw AppFailure(
        'unsupported_feature',
        capability == 'catalogue_search'
            ? 'Product search is not available on this service yet. Photograph the barcode or package label.'
            : capability == 'comparison'
            ? 'Sourced comparison is not available on this service yet. Your product selections are kept.'
            : capability == 'research_catalogue'
            ? 'Sourced product information is not available on this service yet. Search again after the service is updated.'
            : capability == 'ai_extraction'
            ? 'Automatic cloud reading is unavailable. Reading on this device instead.'
            : 'Label reports are not available on this service yet. Please update the service configuration.',
      );
    }
  }

  Future<JsonMap> _loadMetadata() async {
    final value = await _request('GET', '/v1/meta');
    if (value['api_major'] != 1 ||
        value['contract_schema'] != '1' ||
        value['report_version'] != 'label-report-v1' ||
        value['capabilities'] is! JsonMap) {
      throw const AppFailure(
        'incompatible_service',
        'This service uses an incompatible app contract. Please check the service configuration.',
      );
    }
    if (!_closed) {
      _metadata = value;
      _metadataAt = _clock();
    }
    return value;
  }

  static Uri _validateBase(String url, bool allowLocalHttp) {
    final uri = Uri.tryParse(url.trim());
    final loopback =
        uri != null &&
        const ['localhost', '127.0.0.1', '::1', '[::1]'].contains(uri.host);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !(uri.path.isEmpty || uri.path == '/') ||
        !(uri.scheme == 'https' ||
            (allowLocalHttp && loopback && uri.scheme == 'http'))) {
      throw const AppFailure(
        'configuration',
        'The app’s service address is not configured correctly.',
      );
    }
    return uri;
  }

  Future<SearchPage> search(String query, {String? cursor}) async {
    final text = query.trim();
    if (text.length < 2 || text.length > 128) {
      throw const AppFailure(
        'invalid_input',
        'Enter 2 to 128 characters from the product name or brand.',
      );
    }
    await _requireCapability('catalogue_search');
    return _searchCache.read(
      jsonEncode([text, cursor]),
      () async => SearchPage.fromJson(
        await _request(
          'GET',
          '/v1/catalogue/search',
          query: {'q': text, 'limit': '10', 'cursor': ?cursor},
        ),
      ),
      cacheable: (page) => page.status != 'unavailable',
    );
  }

  Future<ProductReport> loadReport(String barcode) async {
    final code = barcode.trim();
    if (!RegExp(r'^(?:[0-9]{8}|[0-9]{12,14})$').hasMatch(code)) {
      throw const AppFailure(
        'invalid_input',
        'Enter an 8, 12, 13 or 14 digit barcode.',
      );
    }
    await _requireCapability('label_reports');
    return _reportCache.read(
      code,
      () async => ProductReport.fromJson(
        await _request('GET', '/v1/products/$code/report'),
      ),
      // Current-package checks belong only to their confirmed POST receipt.
      cacheable: (report) => report.isHistorical,
    );
  }

  /// Consent is obtained by the capture flow before calling this method.
  /// Cancellation stops this client's upload/response wait; the backend may
  /// already have begun reading a photo. The POST is never replayed here.
  Future<ExtractedLabel> extractPhotos(
    Map<int, Uint8List> photos, {
    Future<void>? abortTrigger,
  }) async {
    if (photos.isEmpty ||
        photos.length > 3 ||
        photos.keys.any((slot) => slot < 0 || slot > 2) ||
        photos.values.any((bytes) => bytes.isEmpty || bytes.length > 900000)) {
      throw const AppFailure(
        'invalid_photo',
        'Choose a clearer package photo.',
      );
    }
    await _untilCancelled(_requireCapability('ai_extraction'), abortTrigger);
    String? token;
    try {
      token = await _untilCancelled(
        Future<String?>.sync(_auth.token).timeout(authTimeout),
        abortTrigger,
      );
    } on AppFailure catch (failure) {
      if (failure.kind == 'cancelled') rethrow;
      throw const AppFailure(
        'authentication',
        'Automatic scanner access is unavailable. Try again.',
      );
    } catch (_) {
      throw const AppFailure(
        'authentication',
        'Automatic scanner access is unavailable. Try again.',
      );
    }
    if (token == null || token.isEmpty) {
      throw const AppFailure(
        'authentication',
        'Automatic scanner access is unavailable. Try again.',
      );
    }
    final result = await _request(
      'POST',
      '/v1/ai/extract',
      token: token,
      readOnly: true,
      abortTrigger: abortTrigger,
      requestTimeout: const Duration(seconds: 60),
      body: {
        'privacy_consent': true,
        'images': [
          for (final entry in photos.entries)
            {
              'slot': const ['front', 'back', 'barcode'][entry.key],
              'mime_type': 'image/png',
              'data_base64': base64Encode(entry.value),
            },
        ],
      },
    );
    if (result['status'] != 'extracted' || result['extraction'] is! JsonMap) {
      throw const AppFailure(
        'invalid_response',
        'The photo could not be read. Try a clearer photo.',
      );
    }
    final storage = result['storage'];
    if (storage != null &&
        (storage is! JsonMap || storage['status'] is! String)) {
      throw const AppFailure(
        'invalid_response',
        'The photo could not be read reliably. Try again.',
      );
    }
    return ExtractedLabel.fromJson(
      result['extraction'] as JsonMap,
      storageStatus: storage == null ? null : (storage as JsonMap)['status'],
    );
  }

  Future<T> _untilCancelled<T>(
    Future<T> operation,
    Future<void>? abortTrigger,
  ) => abortTrigger == null
      ? operation
      : Future.any([
          operation,
          abortTrigger.then<T>((_) {
            throw const AppFailure('cancelled', 'Reading stopped.');
          }),
        ]);

  Future<List<ResearchedCandidate>> researchByBarcode(String code) async {
    if (!validProductBarcode(code)) return const [];
    final metadata = await _serviceMetadata();
    if ((metadata['capabilities'] as JsonMap)['research_catalogue'] != true) {
      return const [];
    }
    final value = await _request(
      'GET',
      '/v1/researched/products/by-barcode/$code',
    );
    final candidates = value['candidates'];
    if (value['schema_version'] != '1' ||
        value['barcode'] != code ||
        candidates is! List ||
        candidates.length > 20) {
      throw const AppFailure(
        'invalid_response',
        'Product references could not be read.',
      );
    }
    return List.unmodifiable(
      candidates.map((v) => ResearchedCandidate.fromJson(v as JsonMap)),
    );
  }

  Future<ResearchSearchPage> searchResearch(
    String query, {
    String? cursor,
  }) async {
    final text = query.trim();
    if (text.length < 2 || text.length > 128) {
      throw const AppFailure(
        'invalid_input',
        'Enter 2 to 128 characters from the product name or brand.',
      );
    }
    final metadata = await _serviceMetadata();
    if ((metadata['capabilities'] as JsonMap)['research_catalogue'] != true) {
      return ResearchSearchPage.empty();
    }
    return _researchSearchCache.read(
      jsonEncode([text, cursor]),
      () async => ResearchSearchPage.fromJson(
        await _request(
          'GET',
          '/v1/researched/products/search',
          query: {'q': text, 'limit': '10', 'cursor': ?cursor},
        ),
      ),
      cacheable: (page) => page.status != 'unavailable',
    );
  }

  Future<ResearchedProduct> loadResearchProduct(String entryId) async {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(entryId)) {
      throw const AppFailure(
        'invalid_input',
        'This product reference is invalid. Search again.',
      );
    }
    await _requireCapability('research_catalogue');
    return _researchDetailCache.read(entryId, () async {
      JsonMap value;
      try {
        value = await _request('GET', '/v1/researched/products/$entryId');
      } on AppFailure catch (error) {
        if (error.kind == 'not_found') {
          throw const AppFailure(
            'not_found',
            'This product source is unavailable. Search again for the latest records.',
          );
        }
        rethrow;
      }
      if (value['status'] != 'found') {
        throw const AppFailure(
          'not_found',
          'This product source is unavailable. Search again for the latest records.',
        );
      }
      final product = ResearchedProduct.fromJson(value);
      if (product.entryId != entryId) {
        throw const AppFailure(
          'invalid_response',
          'The returned product does not match your selection. Search again.',
        );
      }
      return product;
    }, cacheable: (_) => true);
  }

  Future<ProductReport> checkLabel(LabelDraft draft) async {
    final payload = draft.toPayload(); // Validate before creating any identity.
    await _requireCapability('label_reports');
    String? token;
    try {
      if ((_metadata?['capabilities']
              as JsonMap?)?['community_contributions'] ==
          true) {
        token = await _auth.token().timeout(authTimeout, onTimeout: () => null);
      }
    } catch (_) {
      token = null;
    }
    // One POST only. An uncertain write is not replayed silently, including 401.
    return ProductReport.fromJson(
      await _request('POST', '/v1/reports/check', body: payload, token: token),
      confirmedComparisonObservation: payload['observation'] as JsonMap,
    );
  }

  Future<SourcedComparison> compare(
    ComparisonOption a,
    ComparisonOption b, {
    required String requestId,
    required String sessionId,
    required int revision,
  }) async {
    await _requireCapability('comparison');
    if (_metadata?['comparison_version'] != comparisonVersion) {
      throw const AppFailure(
        'unsupported_feature',
        'This service uses a different sourced comparison contract. Your product selections are kept.',
      );
    }
    final body = <String, dynamic>{
      'schema_version': '1',
      'client_request_id': requestId,
      'comparison_session_id': sessionId,
      'input_revision': revision,
      'a': a.input,
      'b': b.input,
    };
    if (comparisonRequestBytes(body) > 64 * 1024) {
      throw const AppFailure(
        'invalid_input',
        'These labels are too large to compare together. Choose a smaller label record.',
      );
    }
    final result = SourcedComparison.fromJson(
      await _request('POST', '/v1/reports/compare', body: body, readOnly: true),
    );
    result.requireRequest(a, b, requestId, sessionId, revision);
    return result;
  }

  Future<JsonMap> _request(
    String method,
    String path, {
    Map<String, String>? query,
    JsonMap? body,
    String? token,
    bool readOnly = false,
    Duration? requestTimeout,
    Future<void>? abortTrigger,
  }) async {
    _ensureOpen();
    final abort = Completer<void>();
    final uri = _base.replace(path: path, queryParameters: query);
    final request =
        http.AbortableRequest(method, uri, abortTrigger: abort.future)
          ..followRedirects = false
          ..headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    final cancelled = Completer<JsonMap>();
    abortTrigger?.then((_) {
      if (!abort.isCompleted) abort.complete();
      if (!cancelled.isCompleted) {
        cancelled.completeError(
          const AppFailure('cancelled', 'Reading stopped.'),
        );
      }
    });
    Future<JsonMap> send() async {
      // Let an already completed cancellation reach the abortable request
      // before sending any body bytes.
      if (abortTrigger != null) await Future<void>.value();
      if (abort.isCompleted) {
        throw const AppFailure('cancelled', 'Reading stopped.');
      }
      return _readResponse(request);
    }

    try {
      return await Future.any([
        send(),
        if (abortTrigger != null) cancelled.future,
      ]).timeout(requestTimeout ?? timeout);
    } on AppFailure {
      rethrow;
    } on http.RequestAbortedException {
      throw const AppFailure('cancelled', 'Reading stopped.');
    } on TimeoutException {
      throw AppFailure(
        'timeout',
        method == 'POST' && !readOnly
            ? 'The save took too long and may have completed. Retry to check the same submission.'
            : 'The service took too long. Check your connection and try again.',
      );
    } catch (_) {
      throw const AppFailure(
        'network',
        'We could not connect to the service. Check your connection and try again.',
      );
    } finally {
      if (!abort.isCompleted) abort.complete();
    }
  }

  Future<JsonMap> _readResponse(http.BaseRequest request) async {
    final response = await _client.send(request);
    if ((response.contentLength ?? 0) > maxResponseBytes) {
      await response.stream.listen((_) {}).cancel();
      throw const AppFailure(
        'response_too_large',
        'This report is too large to open safely in the app.',
      );
    }
    final bytes = <int>[];
    await for (final chunk in response.stream) {
      if (bytes.length + chunk.length > maxResponseBytes) {
        throw const AppFailure(
          'response_too_large',
          'This report is too large to open safely in the app.',
        );
      }
      bytes.addAll(chunk);
    }
    final code = response.statusCode;
    if (code == 404) {
      throw const AppFailure(
        'not_found',
        'This barcode needs more information. Photograph the front and back of the package.',
      );
    }
    if (code == 422 || code == 400) {
      throw const AppFailure(
        'invalid_input',
        'Check the entered facts or search text and try again. A search cursor may have expired after a catalogue update.',
      );
    }
    if (code == 429) {
      throw const AppFailure(
        'rate_limited',
        'The service is busy. Please wait before trying again.',
      );
    }
    if (code == 401 || code == 403) {
      throw const AppFailure(
        'authentication',
        'The automatic scanner identity is unavailable. Please try again.',
      );
    }
    if (code < 200 || code >= 300) {
      throw const AppFailure(
        'unavailable',
        'The service is temporarily unavailable. Please try again later.',
      );
    }
    try {
      final value = jsonDecode(utf8.decode(bytes));
      if (value is! Map<String, dynamic>) throw const FormatException();
      if (value['status'] == 'not_found' &&
          !value.containsKey('search_version')) {
        throw const AppFailure(
          'not_found',
          'This barcode needs more information. Photograph the front and back of the package.',
        );
      }
      return value;
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
        'invalid_response',
        'The service returned data we could not read. Please try again.',
      );
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _metadata = null;
    _metadataAt = null;
    _metadataPending = null;
    _searchCache.close();
    _reportCache.close();
    _researchSearchCache.close();
    _researchDetailCache.close();
    _client.close();
  }
}

/// Public validated DTOs only. Completed entries have a fixed expiry and LRU
/// bound; in-flight reads share a future and failures are never retained.
class _PublicReadCache<T> {
  _PublicReadCache({
    required this.ttl,
    required this.maxEntries,
    required this.clock,
  });

  final Duration ttl;
  final int maxEntries;
  final DateTime Function() clock;
  final _entries = <String, _PublicCacheEntry<T>>{};
  final _pending = <String, Future<T>>{};
  bool _closed = false;

  Future<T> read(
    String key,
    Future<T> Function() load, {
    required bool Function(T) cacheable,
  }) {
    final now = clock();
    _entries.removeWhere((_, entry) => !now.isBefore(entry.expiresAt));
    final cached = _entries.remove(key);
    if (cached != null) {
      _entries[key] = cached;
      return Future.value(cached.value);
    }
    final pending = _pending[key];
    if (pending != null) return pending;
    late final Future<T> operation;
    operation = Future<T>.sync(load)
        .then((value) {
          if (!_closed && cacheable(value)) {
            _entries[key] = _PublicCacheEntry(value, clock().add(ttl));
            while (_entries.length > maxEntries) {
              _entries.remove(_entries.keys.first);
            }
          }
          return value;
        })
        .whenComplete(() {
          if (identical(_pending[key], operation)) _pending.remove(key);
        });
    _pending[key] = operation;
    return operation;
  }

  void close() {
    _closed = true;
    _entries.clear();
    _pending.clear();
  }
}

class _PublicCacheEntry<T> {
  const _PublicCacheEntry(this.value, this.expiresAt);
  final T value;
  final DateTime expiresAt;
}
