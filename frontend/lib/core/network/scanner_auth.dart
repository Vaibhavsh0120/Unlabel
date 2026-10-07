// Public constructor names are kept separate from private backing fields.
// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

import '../accounts/account_auth.dart';

abstract interface class ScannerAuth {
  /// Null means automatic authentication is unavailable; analysis still runs.
  Future<String?> token();
}

class UnavailableScannerAuth implements ScannerAuth {
  const UnavailableScannerAuth();
  @override
  Future<String?> token() async => null;
}

/// The Firebase SDK owns credentials and token refresh. The app never writes
/// tokens to its report/history preferences. Guests use anonymous credentials;
/// signed-in scanner users retain their SDK-managed password session.
class SingleFlightScannerAuth implements ScannerAuth {
  SingleFlightScannerAuth({
    required Future<String?> Function() resolve,
    this.timeout = const Duration(seconds: 8),
  }) : _resolve = resolve;
  final Future<String?> Function() _resolve;
  final Duration timeout;
  Future<String?>? _pending;

  @override
  Future<String?> token() {
    // Timing out a caller does not abandon/coalesce away an SDK operation that
    // may still be creating its anonymous user in the background.
    final operation = _pending ??= Future<String?>.sync(_resolve)
        .catchError((Object _) => null)
        .whenComplete(() => _pending = null);
    return operation.timeout(timeout, onTimeout: () => null);
  }
}

class FirebaseScannerAuth extends SingleFlightScannerAuth {
  FirebaseScannerAuth({required FirebaseOptions options, super.timeout})
    : super(resolve: () => _sdkToken(options));

  static Future<String?> _sdkToken(FirebaseOptions options) async {
    final auth = await resolveAccountFirebaseAuth(options);
    var user = auth.currentUser;
    if (user != null &&
        !user.isAnonymous &&
        !user.providerData.any(
          (provider) => provider.providerId == 'password',
        )) {
      return null;
    }
    user ??= (await auth.signInAnonymously()).user;
    return user?.getIdToken();
  }
}
