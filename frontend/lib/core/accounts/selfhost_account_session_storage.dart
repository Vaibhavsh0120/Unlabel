import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/app_failure.dart';

final class StoredSelfhostAccountSession {
  const StoredSelfhostAccountSession({
    required this.userId,
    required this.refreshToken,
  });

  final String userId;
  final String refreshToken;
}

abstract interface class SelfhostAccountSessionStorage {
  Future<StoredSelfhostAccountSession?> read();
  Future<void> write(StoredSelfhostAccountSession session);
  Future<void> delete();
}

final class SecureSelfhostAccountSessionStorage
    implements SelfhostAccountSessionStorage {
  const SecureSelfhostAccountSessionStorage(this._storage);

  static const _key = 'unlabel.selfhost.account-session.v1';
  static final _userId = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
  static final _token = RegExp(r'^[\x21-\x7e]{1,8192}$');

  final FlutterSecureStorage _storage;

  @override
  Future<StoredSelfhostAccountSession?> read() async {
    final encoded = await _storage.read(key: _key);
    if (encoded == null) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(encoded);
    } on FormatException {
      await delete();
      throw _invalidStoredSession;
    }
    if (decoded is! Map ||
        decoded['user_id'] is! String ||
        decoded['refresh_token'] is! String) {
      await delete();
      throw _invalidStoredSession;
    }
    final userId = decoded['user_id'] as String;
    final refreshToken = decoded['refresh_token'] as String;
    if (!_userId.hasMatch(userId) || !_token.hasMatch(refreshToken)) {
      await delete();
      throw _invalidStoredSession;
    }
    return StoredSelfhostAccountSession(
      userId: userId,
      refreshToken: refreshToken,
    );
  }

  @override
  Future<void> write(StoredSelfhostAccountSession session) => _storage.write(
    key: _key,
    value: jsonEncode({
      'user_id': session.userId,
      'refresh_token': session.refreshToken,
    }),
  );

  @override
  Future<void> delete() => _storage.delete(key: _key);

  static const _invalidStoredSession = AppFailure(
    'session_restore_failed',
    'Your saved sign-in could not be restored. Please sign in again.',
  );
}
