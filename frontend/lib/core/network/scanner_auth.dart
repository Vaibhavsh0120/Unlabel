// Public constructor names are kept separate from private backing fields.
// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

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
/// tokens to its report/history preferences, and creates only anonymous users.
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
    final app = Firebase.apps.isEmpty
        ? await Firebase.initializeApp(options: options)
        : Firebase.app();
    if (app.options.projectId != options.projectId ||
        app.options.appId != options.appId) {
      return null;
    }
    final auth = FirebaseAuth.instanceFor(app: app);
    var user = auth.currentUser;
    // An unrelated non-anonymous identity is never reused for scanner writes.
    if (user != null && !user.isAnonymous) return null;
    user ??= (await auth.signInAnonymously()).user;
    return user?.getIdToken();
  }
}
