import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/app_failure.dart';
import 'google_account_provider.dart';

class AccountIdentity {
  const AccountIdentity({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.providers = const {},
  });
  final String uid;
  // Displayed from the SDK only; never copied into report preferences or API data.
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final Set<String> providers;

  bool get hasGoogle => providers.contains('google.com');
  bool get hasPassword => providers.contains('password');
}

abstract class AccountAuth extends ChangeNotifier {
  AccountIdentity? get identity;
  Future<void> start();
  Future<void> signIn(String email, String password);
  Future<void> create(String email, String password);
  Future<void> createWithName(
    String email,
    String password, {
    String? displayName,
  }) => create(email, password);
  Future<void> signInGoogle() async => throw _unsupported;
  Future<void> linkGoogle() async => throw _unsupported;
  Future<void> linkPassword(String email, String password) async =>
      throw _unsupported;
  Future<String> verifyPasswordResetCode(String code) async =>
      throw _unsupported;
  Future<void> confirmPasswordReset(String code, String password) async =>
      throw _unsupported;
  Future<void> resetPassword(String email);
  Future<void> signOut();
  Future<String> token(String expectedUid);

  AppFailure get _unsupported => const AppFailure(
    'account_unavailable',
    'This sign-in action is unavailable on this platform. You can keep using Unlabel as a guest.',
  );
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
  FirebaseAccountAuth({
    required this.options,
    String? googleClientId,
    String? googleServerClientId,
    @visibleForTesting FirebaseAuth? firebaseAuth,
    @visibleForTesting Future<AuthCredential> Function()? googleCredential,
    @visibleForTesting Future<void> Function()? googleSignOut,
  }) : _providedAuth = firebaseAuth {
    final google = NativeGoogleAccountProvider(
      clientId:
          googleClientId ??
          (defaultTargetPlatform == TargetPlatform.iOS
              ? options.iosClientId
              : null),
      serverClientId: googleServerClientId,
    );
    _googleCredential = googleCredential ?? google.credential;
    _googleSignOut = googleSignOut ?? google.signOut;
  }
  final FirebaseOptions options;
  final FirebaseAuth? _providedAuth;
  late final Future<AuthCredential> Function() _googleCredential;
  late final Future<void> Function() _googleSignOut;
  FirebaseAuth? _auth;
  StreamSubscription<User?>? _subscription;
  AccountIdentity? _identity;
  Future<void>? _starting;
  Future<Object?>? _operation;
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
      final auth = _auth =
          _providedAuth ?? await resolveAccountFirebaseAuth(options);
      if (_disposed) return;
      // authStateChanges waits for the SDK's persisted-session restoration.
      final first = Completer<void>();
      _subscription = auth.authStateChanges().listen(
        (user) {
          if (_disposed) {
            if (!first.isCompleted) first.complete();
            return;
          }
          _publishIdentity(user);
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

  void _publishIdentity(User? user) {
    if (_disposed) return;
    UserInfo? googleProfile;
    for (final provider in user?.providerData ?? <UserInfo>[]) {
      if (provider.providerId == 'google.com') googleProfile = provider;
    }
    _identity = user == null || user.isAnonymous
        ? null
        : AccountIdentity(
            uid: user.uid,
            email: user.email,
            displayName: user.displayName ?? googleProfile?.displayName,
            photoUrl: googleProfile?.photoURL ?? user.photoURL,
            providers: Set.unmodifiable(
              user.providerData.map((provider) => provider.providerId),
            ),
          );
    notifyListeners();
  }

  Future<T> _run<T>(Future<T> Function(FirebaseAuth) operation) async {
    try {
      await start();
      if (_disposed) throw _accountChanged;
      if (_operation != null) {
        throw const AppFailure(
          'account_busy',
          'The previous sign-in action is still finishing. Please wait before trying again.',
        );
      }
      late final Future<T> pending;
      pending = operation(_auth!).whenComplete(() {
        if (identical(_operation, pending)) _operation = null;
      });
      _operation = pending;
      // Timing out releases the form, not the SDK operation. Keep its single-
      // flight future until completion so an uncertain request is never replayed.
      return await pending.timeout(
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
    } on GoogleSignInException catch (error) {
      throw switch (error.code) {
        GoogleSignInExceptionCode.canceled => const AppFailure(
          'account_cancelled',
          'Google sign-in was cancelled. You can try again when ready.',
        ),
        _ => const AppFailure(
          'account_unavailable',
          'Google sign-in could not finish. Try again or use email.',
        ),
      };
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
    _requireGuest(auth);
    await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    _publishIdentity(auth.currentUser);
  });

  @override
  Future<void> create(String email, String password) =>
      createWithName(email, password);

  @override
  Future<void> createWithName(
    String email,
    String password, {
    String? displayName,
  }) => _run((auth) async {
    final name = displayName?.trim();
    if (name != null &&
        (name.isEmpty ||
            name.runes.length > 80 ||
            RegExp(r'[\x00-\x1f\x7f]').hasMatch(name))) {
      throw const AppFailure(
        'invalid_name',
        'Enter a name of up to 80 characters.',
      );
    }
    final current = auth.currentUser;
    _requireGuest(auth);
    final UserCredential result;
    if (current?.isAnonymous == true) {
      result = await current!.linkWithCredential(
        EmailAuthProvider.credential(email: email.trim(), password: password),
      );
    } else {
      result = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    }
    final user = result.user;
    if (user == null || auth.currentUser?.uid != user.uid) {
      throw _accountChanged;
    }
    if (name != null) {
      try {
        await user.updateDisplayName(name);
      } catch (_) {
        // Account creation has already succeeded. A cosmetic profile failure
        // must not invite replaying the irreversible create operation.
      }
    }
    if (auth.currentUser?.uid != user.uid) throw _accountChanged;
    _publishIdentity(auth.currentUser);
  });

  @override
  Future<void> signInGoogle() => _run((auth) async {
    _requireGuest(auth);
    if (kIsWeb) {
      await auth.signInWithPopup(_googleProvider());
    } else {
      final credential = await _googleCredential();
      _requireGuest(auth);
      await auth.signInWithCredential(credential);
    }
    _publishIdentity(auth.currentUser);
  });

  @override
  Future<void> linkGoogle() => _run((auth) async {
    final user = _requireSignedIn(auth);
    if (user.providerData.any(
      (provider) => provider.providerId == 'google.com',
    )) {
      throw _providerLinked;
    }
    final UserCredential result;
    if (kIsWeb) {
      result = await user.linkWithPopup(_googleProvider());
    } else {
      final credential = await _googleCredential();
      _requireOwner(auth, user.uid);
      result = await user.linkWithCredential(credential);
    }
    _requireLinkedOwner(auth, user.uid, result);
    _publishIdentity(auth.currentUser);
  });

  @override
  Future<void> linkPassword(String email, String password) =>
      _run((auth) async {
        final user = _requireSignedIn(auth);
        if (user.providerData.any(
          (provider) => provider.providerId == 'password',
        )) {
          throw _providerLinked;
        }
        final result = await user.linkWithCredential(
          EmailAuthProvider.credential(email: email.trim(), password: password),
        );
        _requireLinkedOwner(auth, user.uid, result);
        _publishIdentity(auth.currentUser);
      });

  GoogleAuthProvider _googleProvider() =>
      GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'});

  void _requireGuest(FirebaseAuth auth) {
    if (auth.currentUser != null && !auth.currentUser!.isAnonymous) {
      throw const AppFailure(
        'account_signed_in',
        'You are already signed in. Add another sign-in method in Profile settings.',
      );
    }
  }

  User _requireSignedIn(FirebaseAuth auth) {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous || user.uid != _identity?.uid) {
      throw _accountChanged;
    }
    return user;
  }

  void _requireOwner(FirebaseAuth auth, String uid) {
    if (_disposed || auth.currentUser?.uid != uid || _identity?.uid != uid) {
      throw _accountChanged;
    }
  }

  void _requireLinkedOwner(
    FirebaseAuth auth,
    String uid,
    UserCredential result,
  ) {
    _requireOwner(auth, uid);
    if (result.user?.uid != uid) throw _accountChanged;
  }

  static const _accountChanged = AppFailure(
    'account_changed',
    'Sign-in changed. Reopen Profile before changing sign-in methods.',
  );
  static const _providerLinked = AppFailure(
    'provider_linked',
    'This sign-in method is already connected to your account.',
  );

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
  Future<String> verifyPasswordResetCode(String code) => _run((auth) async {
    _checkResetCode(code);
    return auth.verifyPasswordResetCode(code);
  });

  @override
  Future<void> confirmPasswordReset(String code, String password) =>
      _run((auth) async {
        _checkResetCode(code);
        await auth.confirmPasswordReset(code: code, newPassword: password);
      });

  void _checkResetCode(String code) {
    if (code.isEmpty || code.length > 2048) {
      throw _authFailure('invalid-action-code');
    }
  }

  @override
  Future<void> signOut() => _run((auth) async {
    await auth.signOut();
    _publishIdentity(auth.currentUser);
    if (!kIsWeb) {
      // Firebase sign-out is authoritative. Failure to clear the optional
      // Google chooser cache cannot restore a Firebase account session.
      try {
        await _googleSignOut();
      } catch (_) {}
    }
  });

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
    'Choose a stronger password with at least 8 characters, a letter and a number.',
  ),
  'email-already-in-use' || 'credential-already-in-use' => const AppFailure(
    'email_in_use',
    'This sign-in method belongs to another account. Sign in to that account instead; your libraries have not been merged.',
  ),
  'account-exists-with-different-credential' => const AppFailure(
    'account_exists',
    'Sign in with your existing method, then add Google in Profile settings.',
  ),
  'provider-already-linked' => const AppFailure(
    'provider_linked',
    'This sign-in method is already connected to your account.',
  ),
  'requires-recent-login' => const AppFailure(
    'reauthentication_required',
    'Sign out and sign in again before adding this sign-in method. Your account library will stay available.',
  ),
  'popup-closed-by-user' || 'cancelled-popup-request' => const AppFailure(
    'account_cancelled',
    'Google sign-in was cancelled. You can try again when ready.',
  ),
  'popup-blocked' => const AppFailure(
    'popup_blocked',
    'Allow the Google sign-in pop-up in your browser, then try again.',
  ),
  'invalid-action-code' || 'expired-action-code' => const AppFailure(
    'invalid_reset_code',
    'This reset link has expired or has already been used. Request a new reset link.',
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
    'This sign-in method is unavailable. Try another method or continue as a guest.',
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
