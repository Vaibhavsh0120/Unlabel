import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_failure.dart';

/// A public identity returned by GoTrue. Token material lives on the session.
final class SelfhostAuthUser {
  const SelfhostAuthUser._({
    required this.id,
    required this.isAnonymous,
    this.email,
    this.displayName,
    required this.providers,
  });

  final String id;
  final bool isAnonymous;
  final String? email;
  final String? displayName;
  final Set<String> providers;

  factory SelfhostAuthUser._parse(Object? value) {
    if (value is! Map<String, Object?> ||
        value['id'] is! String ||
        !_userId.hasMatch(value['id'] as String) ||
        value['is_anonymous'] is! bool) {
      throw _invalidResponse;
    }
    final metadata = value['user_metadata'];
    final application = value['app_metadata'];
    final providers = application is Map ? application['providers'] : null;
    return SelfhostAuthUser._(
      id: value['id'] as String,
      isAnonymous: value['is_anonymous'] as bool,
      email: _boundedText(value['email'], 320),
      displayName: metadata is Map
          ? _boundedText(metadata['display_name'], 160) ??
                _boundedText(metadata['full_name'], 160) ??
                _boundedText(metadata['name'], 160)
          : null,
      providers: Set.unmodifiable({
        if (providers is List && providers.contains('email')) 'password',
        if (providers is List && providers.contains('google')) 'google.com',
      }),
    );
  }

  static String? _boundedText(Object? value, int limit) =>
      value is String && value.length <= limit && value.trim().isNotEmpty
      ? value.trim()
      : null;
}

/// Memory-only credentials. Keep these out of report, guest, and log storage.
final class SelfhostAuthSession {
  const SelfhostAuthSession._({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final SelfhostAuthUser user;
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  bool needsRefresh(DateTime now) =>
      !expiresAt.isAfter(now.add(const Duration(seconds: 30)));
}

/// A recovery grant can update a password without activating a scanner session.
final class SelfhostRecoveryGrant {
  const SelfhostRecoveryGrant._(this._session);

  final SelfhostAuthSession _session;
}

/// Redacted provider failure. Only a known, definitively invalid session can
/// trigger replacement of a guest identity.
final class SelfhostAuthFailure extends AppFailure {
  const SelfhostAuthFailure(super.kind, super.userMessage);

  bool get sessionInvalid => kind == 'session_expired';
}

final _userId = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);
final _tokenCharacters = RegExp(r'^[\x21-\x7e]+$');
const _invalidResponse = SelfhostAuthFailure(
  'invalid_auth_response',
  'Sign-in returned an unexpected response. Please try again.',
);
const _invalidInput = SelfhostAuthFailure(
  'invalid_auth_input',
  'Check your sign-in details and try again.',
);

/// Opt-in transport for Unlabel's self-hosted `/auth/v1` proxy.
///
/// The caller owns the injected client and session storage strategy. This
/// transport never initializes Firebase or persists anything in preferences.
final class SelfhostAuthClient {
  SelfhostAuthClient({
    required Uri origin,
    required this._client,
    DateTime Function()? now,
    this.timeout = const Duration(seconds: 10),
    bool allowInsecureLoopback = false,
  }) : _origin = origin,
       _now = now ?? DateTime.now {
    final loopback =
        origin.host == 'localhost' ||
        origin.host == '127.0.0.1' ||
        origin.host == '::1';
    final secure =
        origin.scheme == 'https' ||
        (allowInsecureLoopback && loopback && origin.scheme == 'http');
    if (!secure ||
        origin.host.isEmpty ||
        origin.authority.contains('@') ||
        origin.hasQuery ||
        origin.hasFragment ||
        (origin.path.isNotEmpty && origin.path != '/') ||
        timeout <= Duration.zero) {
      throw ArgumentError(
        'Expected a trusted HTTPS backend origin and timeout.',
      );
    }
  }

  final Uri _origin;
  final http.Client _client;
  final DateTime Function() _now;
  final Duration timeout;
  static const _maxRequestBytes = 128 * 1024;
  static const _maxResponseBytes = 256 * 1024;

  /// Returns null when server signup completed without authenticating the user.
  /// This covers email confirmation and sanitized duplicate-signup responses.
  Future<SelfhostAuthSession?> signUpEmail({
    required String email,
    required String password,
    String? displayName,
    Uri? redirectTo,
  }) async {
    final name = displayName?.trim();
    if (name != null && name.length > 160) throw _invalidInput;
    final result = await _request(
      'POST',
      '/signup',
      query: _redirectQuery(redirectTo),
      body: {
        'email': _email(email),
        'password': _password(password),
        if (name != null && name.isNotEmpty) 'data': {'display_name': name},
      },
    );
    if (result.containsKey('access_token') ||
        result.containsKey('refresh_token')) {
      return _session(result, anonymous: false);
    }
    if (SelfhostAuthUser._parse(result).isAnonymous) throw _invalidResponse;
    return null;
  }

  Future<SelfhostAuthSession> signInPassword({
    required String email,
    required String password,
  }) => _grant('password', {
    'email': _email(email),
    'password': _password(password),
  }, anonymous: false);

  /// The platform sign-in SDK acquires the Google ID token and optional nonce.
  Future<SelfhostAuthSession> signInGoogle({
    required String idToken,
    String? nonce,
  }) => _grant('id_token', {
    'provider': 'google',
    'id_token': _requestToken(idToken, 16384),
    if (nonce != null) 'nonce': _requestToken(nonce, 512),
  }, anonymous: false);

  Future<SelfhostAuthSession> signInGuest() async => _session(
    await _request('POST', '/signup', body: const {}),
    anonymous: true,
  );

  Future<SelfhostAuthSession> refresh(SelfhostAuthSession session) async {
    final renewed = await _grant('refresh_token', {
      'refresh_token': session.refreshToken,
    }, anonymous: session.user.isAnonymous);
    if (renewed.user.id != session.user.id) throw _invalidResponse;
    return renewed;
  }

  Future<SelfhostAuthSession> restoreAccountSession({
    required String userId,
    required String refreshToken,
  }) async {
    if (!_userId.hasMatch(userId)) throw _invalidResponse;
    final renewed = await _grant('refresh_token', {
      'refresh_token': _requestToken(refreshToken, 8192),
    }, anonymous: false);
    if (renewed.user.isAnonymous || renewed.user.id != userId) {
      throw _invalidResponse;
    }
    return renewed;
  }

  Future<SelfhostAuthUser> user(SelfhostAuthSession session) async {
    final user = SelfhostAuthUser._parse(
      await _request('GET', '/user', token: session.accessToken),
    );
    if (user.id != session.user.id) throw _invalidResponse;
    return user;
  }

  Future<void> signOut(SelfhostAuthSession session) async {
    await _request(
      'POST',
      '/logout',
      query: const {'scope': 'local'},
      token: session.accessToken,
    );
  }

  /// Always expose a neutral result to callers. A successful request does not
  /// reveal whether the email address belongs to an account.
  Future<void> requestRecovery({required String email, Uri? redirectTo}) async {
    await _request(
      'POST',
      '/recover',
      query: _redirectQuery(redirectTo),
      body: {'email': _email(email)},
    );
  }

  /// For a recovery template that delivers a token hash. Link routing and
  /// template rollout are the responsibility of the deployment and caller.
  Future<SelfhostRecoveryGrant> verifyRecovery(String tokenHash) async =>
      SelfhostRecoveryGrant._(
        _session(
          await _request(
            'POST',
            '/verify',
            body: {
              'type': 'recovery',
              'token_hash': _requestToken(tokenHash, 4096),
            },
          ),
          anonymous: false,
        ),
      );

  Future<void> updateRecoveredPassword(
    SelfhostRecoveryGrant grant,
    String password,
  ) async {
    final session = grant._session;
    final user = SelfhostAuthUser._parse(
      await _request(
        'PUT',
        '/user',
        body: {'password': _password(password)},
        token: session.accessToken,
      ),
    );
    if (user.id != session.user.id || user.isAnonymous) throw _invalidResponse;
  }

  Future<SelfhostAuthSession> _grant(
    String grant,
    Map<String, Object?> body, {
    required bool anonymous,
  }) async => _session(
    await _request('POST', '/token', query: {'grant_type': grant}, body: body),
    anonymous: anonymous,
  );

  SelfhostAuthSession _session(
    Map<String, Object?> result, {
    required bool anonymous,
  }) {
    final token = result['access_token'];
    final refresh = result['refresh_token'];
    final tokenType = result['token_type'];
    final expiresIn = result['expires_in'];
    if (!_validToken(token, 8192) ||
        !_validToken(refresh, 8192) ||
        tokenType is! String ||
        tokenType.toLowerCase() != 'bearer' ||
        expiresIn is! int ||
        expiresIn <= 0 ||
        expiresIn > 604800) {
      throw _invalidResponse;
    }
    final user = SelfhostAuthUser._parse(result['user']);
    if (user.isAnonymous != anonymous) throw _invalidResponse;
    return SelfhostAuthSession._(
      user: user,
      accessToken: token as String,
      refreshToken: refresh as String,
      expiresAt: _now().toUtc().add(Duration(seconds: expiresIn)),
    );
  }

  Future<Map<String, Object?>> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
    String? token,
  }) async {
    final abort = Completer<void>();
    final request =
        http.AbortableRequest(
            method,
            _origin.replace(path: '/auth/v1$path', queryParameters: query),
            abortTrigger: abort.future,
          )
          ..followRedirects = false
          ..headers['Accept'] = 'application/json';
    if (body != null) {
      final bytes = utf8.encode(jsonEncode(body));
      if (bytes.length > _maxRequestBytes) throw _invalidInput;
      request.headers['Content-Type'] = 'application/json';
      request.bodyBytes = bytes;
    }
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    try {
      return await _response(request).timeout(timeout);
    } on SelfhostAuthFailure {
      rethrow;
    } on TimeoutException {
      throw const SelfhostAuthFailure(
        'account_timeout',
        'Sign-in is taking too long. Check your connection and try again.',
      );
    } catch (_) {
      throw const SelfhostAuthFailure(
        'account_unavailable',
        'We could not reach sign-in. Your local reports are still available.',
      );
    } finally {
      abort.complete();
    }
  }

  Future<Map<String, Object?>> _response(http.BaseRequest request) async {
    final response = await _client.send(request);
    if ((response.contentLength ?? 0) > _maxResponseBytes) {
      await response.stream.listen((_) {}).cancel();
      throw _invalidResponse;
    }
    final bytes = <int>[];
    await for (final chunk in response.stream) {
      if (bytes.length + chunk.length > _maxResponseBytes) {
        throw _invalidResponse;
      }
      bytes.addAll(chunk);
    }
    final code = response.statusCode;
    Map<String, Object?>? parsed;
    if (bytes.isEmpty) {
      parsed = const {};
    } else {
      try {
        final json = jsonDecode(utf8.decode(bytes));
        if (json is Map<String, Object?>) parsed = json;
      } on FormatException {
        // Invalid provider bodies are never shown or logged.
      }
    }
    if (code < 200 || code >= 300) throw _failure(code, parsed);
    if (parsed == null) throw _invalidResponse;
    return parsed;
  }

  static SelfhostAuthFailure _failure(int status, Map<String, Object?>? body) {
    final providerCode = body?['error_code'] ?? body?['code'] ?? body?['error'];
    if (status == 429 || status >= 500) {
      return SelfhostAuthFailure(
        status == 429 ? 'rate_limited' : 'account_unavailable',
        'Sign-in is temporarily unavailable. Please wait and try again.',
      );
    }
    if (status >= 300 && status < 400) return _invalidResponse;
    return switch (providerCode) {
      'refresh_token_not_found' ||
      'refresh_token_already_used' ||
      'session_not_found' ||
      'session_expired' ||
      'user_not_found' => const SelfhostAuthFailure(
        'session_expired',
        'This sign-in session has ended. Sign in again to reconnect.',
      ),
      'invalid_credentials' => const SelfhostAuthFailure(
        'invalid_credentials',
        'Email or password is incorrect.',
      ),
      'email_not_confirmed' => const SelfhostAuthFailure(
        'email_not_confirmed',
        'Confirm your email before signing in.',
      ),
      'weak_password' => const SelfhostAuthFailure(
        'weak_password',
        'Choose a stronger password and try again.',
      ),
      'otp_expired' => const SelfhostAuthFailure(
        'recovery_expired',
        'This recovery link is invalid or expired. Request a new one.',
      ),
      _ => const SelfhostAuthFailure(
        'account_unavailable',
        'Sign-in could not finish. Please try again.',
      ),
    };
  }

  static bool _validToken(Object? value, int maxLength) =>
      value is String &&
      value.isNotEmpty &&
      value.length <= maxLength &&
      _tokenCharacters.hasMatch(value);

  static String _requestToken(String value, int maxLength) {
    if (!_validToken(value, maxLength)) throw _invalidInput;
    return value;
  }

  static String _email(String value) {
    final email = value.trim();
    if (email.isEmpty || email.length > 320 || !email.contains('@')) {
      throw _invalidInput;
    }
    return email;
  }

  static String _password(String password) {
    if (password.isEmpty || utf8.encode(password).length > 72) {
      throw _invalidInput;
    }
    return password;
  }

  static Map<String, String>? _redirectQuery(Uri? redirect) {
    if (redirect == null) return null;
    if (redirect.scheme != 'https' ||
        redirect.host.isEmpty ||
        redirect.authority.contains('@') ||
        redirect.toString().length > 4096) {
      throw _invalidInput;
    }
    return {'redirect_to': redirect.toString()};
  }
}
