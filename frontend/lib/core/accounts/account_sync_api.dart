import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/app_failure.dart';
import '../models/product_report.dart';
import 'account_data.dart';

abstract interface class AccountSyncTransport {
  Future<bool> available();
  Future<AccountSnapshot> fetch(String token);
  Future<AccountSnapshot> put(String token, AccountMutation mutation);
  void cancelAll();
  void close();
}

class AccountSyncApi implements AccountSyncTransport {
  AccountSyncApi({
    required String baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
    bool allowLocalHttp = kDebugMode,
  }) : _base = _origin(baseUrl, allowLocalHttp),
       _client = client ?? http.Client();
  final Uri _base;
  final http.Client _client;
  final Duration timeout;
  final _active = <Completer<void>>{};
  static const maxResponseBytes = 512 * 1024;
  static Uri _origin(String value, bool allowLocal) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        (uri.scheme != 'https' &&
            !(allowLocal &&
                uri.scheme == 'http' &&
                const ['localhost', '127.0.0.1', '::1'].contains(uri.host)))) {
      throw const AppFailure(
        'invalid_configuration',
        'Private sync requires a valid secure service address.',
      );
    }
    return uri;
  }

  @override
  Future<bool> available() async {
    final meta = await _request('GET', '/v1/meta');
    return meta['api_major'] == 1 &&
        meta['contract_schema'] == '1' &&
        meta['capabilities'] is JsonMap &&
        (meta['capabilities'] as JsonMap)['account_sync'] == true;
  }

  @override
  Future<AccountSnapshot> fetch(String token) async => AccountSnapshot.fromJson(
    await _request('GET', '/v1/account/sync', token: token),
  );
  @override
  Future<AccountSnapshot> put(String token, AccountMutation mutation) async {
    mutation.data.checkSyncSize();
    return AccountSnapshot.fromJson(
      await _request(
        'POST',
        '/v1/account/sync',
        token: token,
        body: mutation.toJson(),
      ),
    );
  }

  Future<JsonMap> _request(
    String method,
    String path, {
    String? token,
    JsonMap? body,
  }) async {
    final abort = Completer<void>();
    _active.add(abort);
    final request =
        http.AbortableRequest(
            method,
            _base.replace(path: path),
            abortTrigger: abort.future,
          )
          ..followRedirects = false
          ..headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      final text = jsonEncode(body);
      if (utf8.encode(text).length > maxResponseBytes) {
        _active.remove(abort);
        throw const AppFailure(
          'sync_capacity',
          'The account library is too large to sync. No reports were dropped.',
        );
      }
      request.headers['Content-Type'] = 'application/json';
      request.body = text;
    }
    try {
      return await _read(request).timeout(timeout);
    } on AppFailure {
      rethrow;
    } on TimeoutException {
      throw const AppFailure(
        'sync_timeout',
        'Sync took too long. Your device data is safe; retry keeps the same pending change.',
      );
    } catch (_) {
      throw const AppFailure(
        'sync_network',
        'Sync could not connect. Your device data is safe. Please try again.',
      );
    } finally {
      _active.remove(abort);
      if (!abort.isCompleted) abort.complete();
    }
  }

  Future<JsonMap> _read(http.BaseRequest request) async {
    final response = await _client.send(request);
    if ((response.contentLength ?? 0) > maxResponseBytes) {
      await response.stream.listen((_) {}).cancel();
      throw const AppFailure(
        'invalid_response',
        'Synced data exceeds the app limit. Your device data was kept.',
      );
    }
    final bytes = <int>[];
    await for (final chunk in response.stream) {
      if (bytes.length + chunk.length > maxResponseBytes) {
        throw const AppFailure(
          'invalid_response',
          'Synced data exceeds the app limit. Your device data was kept.',
        );
      }
      bytes.addAll(chunk);
    }
    switch (response.statusCode) {
      case 401:
      case 403:
        throw const AppFailure(
          'account_authentication',
          'Sign in again to sync. Your local account reports are safe.',
        );
      case 409:
        throw const AppFailure(
          'sync_conflict',
          'Cloud data changed on another device. Choose which library to keep.',
        );
      case 429:
        throw const AppFailure(
          'sync_rate_limited',
          'Too many sync changes. Please wait before trying again.',
        );
      case 400:
      case 413:
      case 422:
        throw const AppFailure(
          'sync_invalid',
          'This account data could not be synced. Check its size and try again. Your local reports were kept.',
        );
    }
    if (response.statusCode != 200) {
      throw const AppFailure(
        'sync_unavailable',
        'Private sync is temporarily unavailable. Your device data is safe.',
      );
    }
    try {
      final data = jsonDecode(utf8.decode(bytes));
      if (data is! JsonMap) throw const FormatException();
      return data;
    } catch (_) {
      throw const AppFailure(
        'invalid_response',
        'The sync service returned data we could not read.',
      );
    }
  }

  @override
  void cancelAll() {
    for (final abort in _active.toList()) {
      if (!abort.isCompleted) abort.complete();
    }
    _active.clear();
  }

  @override
  void close() {
    cancelAll();
    _client.close();
  }
}
