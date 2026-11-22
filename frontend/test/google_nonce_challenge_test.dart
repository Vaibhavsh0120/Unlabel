import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/core/accounts/google_nonce_challenge.dart';
import 'package:unlabel/core/models/app_failure.dart';

String token(Map<String, Object?> claims) =>
    'header.${base64UrlEncode(utf8.encode(jsonEncode(claims))).replaceAll('=', '')}.signature';

void main() {
  test('iOS hashed nonce returns its matching raw proof', () {
    final challenge = GoogleNonceChallenge();
    expect(challenge.raw.length, 43);
    expect(challenge.raw, isNot(GoogleNonceChallenge().raw));
    expect(
      challenge.hash,
      sha256.convert(utf8.encode(challenge.raw)).toString(),
    );
    expect(
      challenge.nonceForToken(token({'nonce': challenge.hash})),
      challenge.raw,
    );
  });

  test(
    'Android token without nonce omits proof, mismatched tokens fail closed',
    () {
      final challenge = GoogleNonceChallenge();
      expect(challenge.nonceForToken(token({'sub': 'synthetic'})), isNull);
      for (final value in [
        'invalid',
        token({'nonce': 'different'}),
        token({'nonce': 1}),
      ]) {
        expect(
          () => challenge.nonceForToken(value),
          throwsA(isA<AppFailure>()),
        );
      }
    },
  );
}
