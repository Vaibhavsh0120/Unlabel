import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/app_failure.dart';
import 'google_nonce_challenge.dart';

/// Native Google authentication requests identity only, without Drive, Contacts
/// or other Google API scopes. The selected account service owns its session.
class NativeGoogleAccountProvider {
  NativeGoogleAccountProvider({
    this.clientId,
    this.serverClientId,
    this.useNonce = false,
  });

  final String? clientId;
  final String? serverClientId;
  final bool useNonce;
  static final _challenge = GoogleNonceChallenge();
  String? _lastNonce;
  String? get nonce => _lastNonce;
  static Future<void>? _initializing;

  Future<AuthCredential> credential() async =>
      GoogleAuthProvider.credential(idToken: await idToken());

  Future<String> idToken() async {
    _lastNonce = null;
    await (_initializing ??= _initialize());
    final google = GoogleSignIn.instance;
    if (!google.supportsAuthenticate()) {
      throw const AppFailure(
        'account_unavailable',
        'Google sign-in is unavailable on this platform. You can use email instead.',
      );
    }
    final account = await google.authenticate();
    final token = account.authentication.idToken;
    if (token == null || token.isEmpty) {
      throw const AppFailure(
        'account_unavailable',
        'Google could not confirm this sign-in. Please try again.',
      );
    }
    if (useNonce) _lastNonce = _challenge.nonceForToken(token);
    return token;
  }

  Future<void> _initialize() async {
    try {
      await GoogleSignIn.instance.initialize(
        clientId: clientId,
        serverClientId: serverClientId,
        nonce: useNonce ? _challenge.hash : null,
      );
    } catch (_) {
      _initializing = null;
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (_initializing != null) {
      await GoogleSignIn.instance.signOut();
    }
  }
}
