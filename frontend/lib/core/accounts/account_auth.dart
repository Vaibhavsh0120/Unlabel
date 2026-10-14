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
    this.googleEmail,
    this.googleDisplayName,
    this.googlePhotoUrl,
    this.providers = const {},
  });
  final String uid;
  // Displayed from the SDK only; never copied into report preferences or API data.
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? googleEmail;
  final String? googleDisplayName;
  final String? googlePhotoUrl;
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
  Future<void> unlinkGoogle({required String password}) async =>
      throw _unsupported;
  Future<void> unlinkPassword() async => throw _unsupported;
  Future<void> changeGoogleAccount({required String password}) async =>
      throw _unsupported;
  Future<void> changeEmail(String email, String currentPassword) async =>
      throw _unsupported;
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async => throw _unsupported;
  Future<void> deleteAccount({
    String? password,
    required Future<void> Function(String uid, String token) deletePrivateData,
    required Future<void> Function() deleteLocalData,
  }) async => throw _unsupported;
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
            displayName: googleProfile?.displayName ?? user.displayName,
            // Firebase can retain an old top-level photo after unlinking. A
            // removed Google provider must not keep supplying that old image.
            photoUrl: googleProfile == null
                ? null
                : googleProfile.photoURL ?? user.photoURL,
            googleEmail: googleProfile?.email,
            googleDisplayName: googleProfile?.displayName,
            googlePhotoUrl:
                googleProfile?.photoURL ??
                (googleProfile == null ? null : user.photoURL),
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

  bool _hasProvider(User user, String provider) =>
      user.providerData.any((value) => value.providerId == provider);

  Future<User> _freshUser(FirebaseAuth auth) async {
    final user = _requireSignedIn(auth);
    await user.reload();
    _requireOwner(auth, user.uid);
    final refreshed = auth.currentUser!;
    _publishIdentity(refreshed);
    return refreshed;
  }

  Future<void> _reauthenticate(
    FirebaseAuth auth,
    User user, {
    String? password,
    bool useGoogle = false,
  }) async {
    final UserCredential result;
    if (!useGoogle && _hasProvider(user, 'password')) {
      if (password == null || password.isEmpty || user.email == null) {
        throw const AppFailure(
          'password_required',
          'Enter your current account password to confirm this change.',
        );
      }
      result = await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: password),
      );
    } else if (_hasProvider(user, 'google.com')) {
      if (kIsWeb) {
        result = await user.reauthenticateWithPopup(_googleProvider());
      } else {
        final credential = await _googleCredential();
        _requireOwner(auth, user.uid);
        result = await user.reauthenticateWithCredential(credential);
      }
    } else {
      throw const AppFailure(
        'account_changed',
        'Your sign-in methods changed. Reopen Profile and try again.',
      );
    }
    _requireLinkedOwner(auth, user.uid, result);
  }

  void _requireBackup(User user, String removing) {
    if (!_hasProvider(user, removing)) {
      throw const AppFailure(
        'provider_not_linked',
        'This sign-in method is already disconnected.',
      );
    }
    final backup = removing == 'google.com' ? 'password' : 'google.com';
    if (!_hasProvider(user, backup)) {
      throw const AppFailure(
        'last_sign_in_method',
        'Keep at least one sign-in method. Connect another method before disconnecting this one.',
      );
    }
  }

  @override
  Future<void> unlinkGoogle({required String password}) => _run((auth) async {
    final user = await _freshUser(auth);
    _requireBackup(user, 'google.com');
    await _reauthenticate(auth, user, password: password);
    _requireOwner(auth, user.uid);
    final result = await user.unlink('google.com');
    _requireOwner(auth, user.uid);
    if (result.uid != user.uid) throw _accountChanged;
    _publishIdentity(auth.currentUser);
  });

  @override
  Future<void> unlinkPassword() => _run((auth) async {
    final user = await _freshUser(auth);
    _requireBackup(user, 'password');
    // Prove access to the method that will remain before removing a password.
    await _reauthenticate(auth, user, useGoogle: true);
    _requireOwner(auth, user.uid);
    final result = await user.unlink('password');
    _requireOwner(auth, user.uid);
    if (result.uid != user.uid) throw _accountChanged;
    _publishIdentity(auth.currentUser);
  });

  @override
  Future<void> changeGoogleAccount({required String password}) => _run((
    auth,
  ) async {
    final user = await _freshUser(auth);
    _requireBackup(user, 'google.com');
    await _reauthenticate(auth, user, password: password);
    _requireOwner(auth, user.uid);
    await user.unlink('google.com');
    _requireOwner(auth, user.uid);
    _publishIdentity(auth.currentUser);
    // Firebase permits only one account for a given provider. The verified
    // password remains available if choosing/linking replacement Google fails.
    try {
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
    } catch (error) {
      _publishIdentity(auth.currentUser);
      if (error is AppFailure && error.kind == 'account_changed') rethrow;
      if (error is FirebaseAuthException &&
          const [
            'credential-already-in-use',
            'email-already-in-use',
            'account-exists-with-different-credential',
          ].contains(error.code)) {
        throw const AppFailure(
          'google_change_incomplete',
          'That Google account belongs to another Unlabel account. Your password still works. Connect a different Google account; no libraries were merged.',
        );
      }
      throw const AppFailure(
        'google_change_incomplete',
        'Google was disconnected, but reconnecting did not finish. Your password still works. Use Connect Google to try again.',
      );
    }
  });

  @override
  Future<void> changeEmail(String email, String currentPassword) =>
      _run((auth) async {
        final user = await _freshUser(auth);
        if (!_hasProvider(user, 'password')) throw _passwordNotLinked;
        await _reauthenticate(auth, user, password: currentPassword);
        _requireOwner(auth, user.uid);
        await user.verifyBeforeUpdateEmail(email.trim());
        _requireOwner(auth, user.uid);
        _publishIdentity(auth.currentUser);
      });

  @override
  Future<void> changePassword(String currentPassword, String newPassword) =>
      _run((auth) async {
        final user = await _freshUser(auth);
        if (!_hasProvider(user, 'password')) throw _passwordNotLinked;
        await _reauthenticate(auth, user, password: currentPassword);
        _requireOwner(auth, user.uid);
        await user.updatePassword(newPassword);
        _requireOwner(auth, user.uid);
        _publishIdentity(auth.currentUser);
      });

  @override
  Future<void> deleteAccount({
    String? password,
    required Future<void> Function(String uid, String token) deletePrivateData,
    required Future<void> Function() deleteLocalData,
  }) => _run((auth) async {
    final user = await _freshUser(auth);
    await _reauthenticate(auth, user, password: password);
    _requireOwner(auth, user.uid);
    final token = await user.getIdToken(true);
    _requireOwner(auth, user.uid);
    if (token == null || token.isEmpty) throw _accountChanged;
    await deletePrivateData(user.uid, token);
    _requireOwner(auth, user.uid);
    try {
      await user.delete();
    } catch (_) {
      throw const AppFailure(
        'account_delete_incomplete',
        'Private cloud data was cleared, but deleting your sign-in did not finish. Confirm your identity and retry deleting the account.',
      );
    }
    // This hook remains inside the underlying SDK operation even if the form's
    // timeout has elapsed, so confirmed late deletion still purges this owner.
    await deleteLocalData();
    _publishIdentity(auth.currentUser);
    if (!kIsWeb) {
      try {
        await _googleSignOut();
      } catch (_) {}
    }
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
  static const _passwordNotLinked = AppFailure(
    'provider_not_linked',
    'Email and password is no longer connected. Reopen Profile to refresh your sign-in methods.',
  );

  @override
  Future<void> resetPassword(String email) => _run((auth) async {
    try {
      await auth.sendPasswordResetEmail(
        email: email.trim(),
        actionCodeSettings: ActionCodeSettings(
          handleCodeInApp: false,
          // Firebase's hosted action widget owns code verification and the
          // password form. Its Continue action returns to this fixed sign-in
          // route, without carrying an email address or a one-time code.
          url: 'https://unlabel-india.vercel.app/#/account-signin',
        ),
      );
    } on FirebaseAuthException catch (error) {
      // A neutral success message avoids revealing whether an email is registered.
      if (error.code != 'user-not-found') rethrow;
    }
  });

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
    'Confirm your identity again before making this account change.',
  ),
  'user-mismatch' => const AppFailure(
    'reauthentication_mismatch',
    'Choose the Google account already connected to this Unlabel account.',
  ),
  'no-such-provider' => const AppFailure(
    'provider_not_linked',
    'This sign-in method is already disconnected. Reopen Profile to refresh it.',
  ),
  'popup-closed-by-user' || 'cancelled-popup-request' => const AppFailure(
    'account_cancelled',
    'Google sign-in was cancelled. You can try again when ready.',
  ),
  'popup-blocked' => const AppFailure(
    'popup_blocked',
    'Allow the Google sign-in pop-up in your browser, then try again.',
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
