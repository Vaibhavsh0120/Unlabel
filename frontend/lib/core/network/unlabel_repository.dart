import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/app_failure.dart';
import '../models/label_draft.dart';
import '../models/product_report.dart';
import 'scanner_auth.dart';

export '../models/app_failure.dart';
export '../models/label_draft.dart';
export '../models/product_report.dart';

class UnlabelRepository {
  UnlabelRepository({
    required String baseUrl,
    http.Client? client,
    ScannerAuth auth = const UnavailableScannerAuth(),
    this.timeout = const Duration(seconds: 15),
    this.authTimeout = const Duration(seconds: 8),
    this.maxResponseBytes = 2 * 1024 * 1024,
    bool allowLocalHttp = kDebugMode,
  }) : _client = client ?? http.Client(),
       // ignore: prefer_initializing_formals
       _auth = auth,
       _base = _validateBase(baseUrl, allowLocalHttp);
  final http.Client _client;
  final ScannerAuth _auth;
  final Uri _base;
  final Duration timeout;
  final Duration authTimeout;
  final int maxResponseBytes;
  JsonMap? _metadata;
  DateTime? _metadataAt;
  Future<JsonMap>? _metadataPending;

  Future<void> _requireCapability(String capability) async {
    if (_metadataAt == null ||
        DateTime.now().difference(_metadataAt!) > const Duration(minutes: 5)) {
      _metadata = null;
    }
    final metadata =
        _metadata ??
        await (_metadataPending ??= _loadMetadata().whenComplete(
          () => _metadataPending = null,
        ));
    final capabilities = metadata['capabilities'] as JsonMap;
    if (capabilities[capability] != true) {
      throw AppFailure(
        'unsupported_feature',
        capability == 'catalogue_search'
            ? 'Product search is not available on this service yet. You can enter a barcode or package label.'
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
    _metadata = value;
    _metadataAt = DateTime.now();
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
    final value = await _request(
      'GET',
      '/v1/catalogue/search',
      query: {'q': text, 'limit': '10', 'cursor': ?cursor},
    );
    return SearchPage.fromJson(value);
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
    return ProductReport.fromJson(
      await _request('GET', '/v1/products/$code/report'),
    );
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
    );
  }

  Future<JsonMap> _request(
    String method,
    String path, {
    Map<String, String>? query,
    JsonMap? body,
    String? token,
  }) async {
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
    try {
      return await _readResponse(request).timeout(timeout);
    } on AppFailure {
      rethrow;
    } on TimeoutException {
      throw AppFailure(
        'timeout',
        method == 'POST'
            ? 'The service took too long. A label save may have completed; retrying the unchanged form uses the same submission.'
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
        'No catalogue report was found for this barcode. You can enter the package label instead.',
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
          'No catalogue report was found for this barcode. You can enter the package label instead.',
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

  void close() => _client.close();
}
