import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/app_failure.dart';

/// Native Google authentication requests identity only, without Drive, Contacts
/// or other Google API scopes. The selected account service owns its session.
class NativeGoogleAccountProvider {
  NativeGoogleAccountProvider({this.clientId, this.serverClientId});

  final String? clientId;
  final String? serverClientId;
  static Future<void>? _initializing;

  Future<AuthCredential> credential() async =>
      GoogleAuthProvider.credential(idToken: await idToken());

  Future<String> idToken() async {
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
    return token;
  }

  Future<void> _initialize() async {
    try {
      await GoogleSignIn.instance.initialize(
        clientId: clientId,
        serverClientId: serverClientId,
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
