import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/app_failure.dart';

class AccountIdentity {
  const AccountIdentity({required this.uid, this.email});
  final String uid;
  // Displayed from the SDK only; never copied into report preferences or API data.
  final String? email;
}

abstract class AccountAuth extends ChangeNotifier {
  AccountIdentity? get identity;
  Future<void> start();
  Future<void> signIn(String email, String password);
  Future<void> create(String email, String password);
  Future<void> resetPassword(String email);
  Future<void> signOut();
  Future<String> token(String expectedUid);
}

Future<FirebaseAuth>? _initializingAuth;

class UnavailableAccountAuth extends AccountAuth {
  @override
  AccountIdentity? get identity => null;
  @override
  Future<void> start() async {}
  AppFailure get _unavailable => const AppFailure(
    'account_unavailable',
    'Sign-in is unavailable on this platform. All guest features remain available.',
  );
  @override
  Future<void> signIn(String email, String password) async =>
      throw _unavailable;
  @override
  Future<void> create(String email, String password) async =>
      throw _unavailable;
  @override
  Future<void> resetPassword(String email) async => throw _unavailable;
  @override
  Future<void> signOut() async {}
  @override
  Future<String> token(String expectedUid) async => throw _unavailable;
}

/// Shared SDK initialization. Neither reading this session nor opening Profile
/// creates an anonymous account. The SDK alone owns persisted credentials.
Future<FirebaseAuth> resolveAccountFirebaseAuth(FirebaseOptions options) async {
  final auth = await (_initializingAuth ??= () async {
    try {
      final app = Firebase.apps.isEmpty
          ? await Firebase.initializeApp(options: options)
          : Firebase.app();
      return FirebaseAuth.instanceFor(app: app);
    } catch (_) {
      _initializingAuth = null;
      rethrow;
    }
  }());
  if (auth.app.options.projectId != options.projectId ||
      auth.app.options.appId != options.appId) {
    throw const AppFailure(
      'account_unavailable',
      'Sign-in is unavailable in this app configuration.',
    );
  }
  return auth;
}

class FirebaseAccountAuth extends AccountAuth {
  FirebaseAccountAuth({required this.options});
  final FirebaseOptions options;
  FirebaseAuth? _auth;
  StreamSubscription<User?>? _subscription;
  AccountIdentity? _identity;
  Future<void>? _starting;
  Future<void>? _operation;
  static const operationTimeout = Duration(seconds: 15);
  bool _disposed = false;
  @override
  AccountIdentity? get identity => _identity;

  @override
  Future<void> start() => (_starting ??= _start()).timeout(
    operationTimeout,
    onTimeout: () => throw const AppFailure(
      'account_unavailable',
      'Sign-in is taking too long. Continue as a guest or try again shortly.',
    ),
  );
  Future<void> _start() async {
    try {
      final auth = _auth = await resolveAccountFirebaseAuth(options);
      if (_disposed) return;
      // authStateChanges waits for the SDK's persisted-session restoration.
      final first = Completer<void>();
      _subscription = auth.authStateChanges().listen(
        (user) {
          if (_disposed) {
            if (!first.isCompleted) first.complete();
            return;
          }
          _identity = user == null || user.isAnonymous
              ? null
              : AccountIdentity(uid: user.uid, email: user.email);
          notifyListeners();
          if (!first.isCompleted) first.complete();
        },
        onError: (Object _) {
          if (!first.isCompleted) {
            first.completeError(
              const AppFailure(
                'account_unavailable',
                'The saved sign-in session could not be restored. You can keep using Unlabel as a guest.',
              ),
            );
          }
        },
      );
      await first.future;
    } catch (_) {
      _starting = null;
      rethrow;
    }
  }

  Future<void> _run(Future<void> Function(FirebaseAuth) operation) async {
    try {
      await start();
      if (_disposed) return;
      if (_operation != null) {
        throw const AppFailure(
          'account_busy',
          'The previous sign-in action is still finishing. Please wait before trying again.',
        );
      }
      late final Future<void> pending;
      pending = operation(_auth!).whenComplete(() {
        if (identical(_operation, pending)) _operation = null;
      });
      _operation = pending;
      // Timing out releases the form, not the SDK operation. Keep its single-
      // flight future until completion so an uncertain request is never replayed.
      await pending.timeout(
        operationTimeout,
        onTimeout: () {
          throw const AppFailure(
            'account_unavailable',
            'Sign-in is taking too long. Continue as a guest while it finishes.',
          );
        },
      );
    } on FirebaseAuthException catch (error) {
      throw _authFailure(error.code);
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
        'account_unavailable',
        'Sign-in could not connect. Please try again. Your local reports are still available.',
      );
    }
  }

  @override
  Future<void> signIn(String email, String password) => _run((auth) async {
    await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  });

  @override
  Future<void> create(String email, String password) => _run((auth) async {
    final current = auth.currentUser;
    if (current != null && !current.isAnonymous) {
      throw const AppFailure(
        'account_signed_in',
        'Sign out before creating another account.',
      );
    }
    if (current?.isAnonymous == true) {
      await current!.linkWithCredential(
        EmailAuthProvider.credential(email: email.trim(), password: password),
      );
    } else {
      await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    }
  });

  @override
  Future<void> resetPassword(String email) => _run((auth) async {
    try {
      await auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      // A neutral success message avoids revealing whether an email is registered.
      if (error.code != 'user-not-found') rethrow;
    }
  });

  @override
  Future<void> signOut() => _run((auth) => auth.signOut());

  @override
  Future<String> token(String expectedUid) async {
    await start();
    final user = _auth!.currentUser;
    if (user == null || user.isAnonymous || user.uid != expectedUid) {
      throw const AppFailure(
        'account_changed',
        'Sign-in changed. Please reopen your profile.',
      );
    }
    final token = await user.getIdToken().timeout(
      operationTimeout,
      onTimeout: () => throw const AppFailure(
        'account_unavailable',
        'Your sign-in session could not connect. Check sync again later.',
      ),
    );
    if (token == null ||
        token.isEmpty ||
        _auth!.currentUser?.uid != expectedUid) {
      throw const AppFailure(
        'account_changed',
        'Your sign-in session changed. Please try again.',
      );
    }
    return token;
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

AppFailure _authFailure(String code) => switch (code) {
  'invalid-email' => const AppFailure(
    'invalid_email',
    'Enter a valid email address.',
  ),
  'weak-password' => const AppFailure(
    'weak_password',
    'Choose a stronger password with at least 6 characters.',
  ),
  'email-already-in-use' || 'credential-already-in-use' => const AppFailure(
    'email_in_use',
    'This email already has an account. Sign in instead.',
  ),
  'invalid-credential' ||
  'wrong-password' ||
  'user-not-found' => const AppFailure(
    'invalid_credentials',
    'The email or password did not match. Check them or reset your password.',
  ),
  'too-many-requests' => const AppFailure(
    'rate_limited',
    'Too many attempts. Please wait before trying again.',
  ),
  'operation-not-allowed' => const AppFailure(
    'account_unavailable',
    'Email sign-in is not available yet. Continue as a guest and try again later.',
  ),
  'user-disabled' => const AppFailure(
    'account_unavailable',
    'This account cannot sign in. You can continue as a guest.',
  ),
  _ => const AppFailure(
    'account_unavailable',
    'Sign-in is unavailable. Please try again. Your local reports are still available.',
  ),
};
