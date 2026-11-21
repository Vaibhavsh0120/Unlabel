import 'dart:convert';
import 'dart:js_interop';

import '../models/app_failure.dart';

@JS('unlabelGoogleOAuth')
external JSPromise<JSString> _googleOAuth(JSString backend, JSString? token);

@JS('unlabelPrepareGoogleOAuth')
external void _prepareGoogleOAuth();

@JS('unlabelCancelGoogleOAuth')
external void _cancelGoogleOAuth();

@JS('unlabelGoogleLoginRedirect')
external JSPromise<JSAny?> _startGoogleRedirect(JSString backend);

@JS('unlabelTakeGoogleRedirect')
external JSString? _takeGoogleRedirect();

Future<void> startGoogleRedirect(String backend) async {
  try {
    await _startGoogleRedirect(backend.toJS).toDart;
  } catch (_) {
    throw const AppFailure(
      'account_unavailable',
      'Google sign-in could not open. Please try again.',
    );
  }
}

Map<String, Object?>? takeGoogleRedirect() {
  final raw = _takeGoogleRedirect()?.toDart;
  if (raw == null) return null;
  final value = jsonDecode(raw);
  return value is Map<String, Object?> ? value : null;
}

void cancelGoogleOAuth() => _cancelGoogleOAuth();

void prepareGoogleOAuth() {
  try {
    _prepareGoogleOAuth();
  } catch (_) {
    throw const AppFailure(
      'popup_blocked',
      'Allow the Google sign-in window and try again.',
    );
  }
}

Future<Map<String, Object?>> googleOAuth(
  String backend, {
  String? token,
}) async {
  try {
    final value = jsonDecode(
      (await _googleOAuth(backend.toJS, token?.toJS).toDart).toDart,
    );
    if (value is Map<String, Object?>) return value;
  } catch (_) {
    throw const AppFailure(
      'account_unavailable',
      'Google sign-in did not finish. Allow the sign-in window and try again.',
    );
  }
  throw const AppFailure(
    'account_unavailable',
    'Google sign-in could not finish.',
  );
}
