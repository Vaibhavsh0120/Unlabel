import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../models/app_failure.dart';

/// One challenge for the SDK's once-per-process initialization. Never persisted.
class GoogleNonceChallenge {
  GoogleNonceChallenge() : raw = _randomNonce();

  static String _randomNonce() {
    final random = Random.secure();
    return base64UrlEncode(List.generate(32, (_) => random.nextInt(256)))
        .replaceAll('=', '');
  }

  final String raw;
  String get hash => sha256.convert(utf8.encode(raw)).toString();

  String? nonceForToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) throw const FormatException();
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (claims is! Map<String, dynamic>) throw const FormatException();
      final nonce = claims['nonce'];
      // Some native platforms ignore initialize(nonce:). GoTrue requires both
      // values absent in that case, and validates both when Google supplies one.
      if (nonce == null) return null;
      if (nonce == hash) return raw;
    } catch (_) {
      // Signature/audience verification still belongs to the identity service.
    }
    throw const AppFailure(
      'google_nonce_mismatch',
      'Google returned an outdated sign-in response. Please try signing in again.',
    );
  }
}
