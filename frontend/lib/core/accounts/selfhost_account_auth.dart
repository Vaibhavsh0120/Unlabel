import 'package:google_sign_in/google_sign_in.dart';

import '../models/app_failure.dart';
import '../network/scanner_auth.dart';
import 'account_auth.dart';
import 'selfhost_auth_client.dart';
import 'selfhost_account_session_storage.dart';

/// Staged composition of the self-hosted account and scanner credentials.
/// Guest refresh/signup never touches the device's catalogue or library state.
final class SelfhostAccountAuth extends AccountAuth {
  SelfhostAccountAuth({
    required this._client,
    this._googleIdToken,
    this._googleNonce,
    this._googleOAuth,
    this._googleLoginRedirect,
    this._takeGoogleRedirect,
    this._prepareGoogleOAuth,
    this._cancelGoogleOAuth,
    this._emailRedirect,
    this._recoveryRedirect,
    this._sessionStorage,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final SelfhostAuthClient _client;
  final Future<String> Function()? _googleIdToken;
  final String? Function()? _googleNonce;
  final Future<Map<String, Object?>> Function(String? token)? _googleOAuth;
  final Future<void> Function()? _googleLoginRedirect;
  final Map<String, Object?>? Function()? _takeGoogleRedirect;
  final void Function()? _prepareGoogleOAuth;
  final void Function()? _cancelGoogleOAuth;
  final Uri? _emailRedirect;
  final Uri? _recoveryRedirect;
  final SelfhostAccountSessionStorage? _sessionStorage;
  final DateTime Function() _now;
  late final ScannerAuth scannerAuth = SingleFlightScannerAuth(
    resolve: _scannerToken,
  );
  SelfhostAuthSession? _account;
  SelfhostAuthSession? _guest;
  Future<SelfhostAuthSession>? _accountRefresh;
  Future<void>? _startup;
  bool _starting = false;
  bool _busy = false;
  bool _signingOut = false;
  bool _disposed = false;
  int _generation = 0;

  @override
  AccountIdentity? get identity {
    final user = _account?.user;
    return user == null
        ? null
        : AccountIdentity(
            uid: user.id,
            email: user.email,
            displayName: user.displayName,
            photoUrl: user.photoUrl,
            googleEmail: user.providers.contains('google.com')
                ? user.email
                : null,
            googleDisplayName: user.providers.contains('google.com')
                ? user.displayName
                : null,
            googlePhotoUrl: user.providers.contains('google.com')
                ? user.photoUrl
                : null,
            providers: user.providers,
          );
  }

  @override
  Future<void> start() => _startup ??= _restoreSession();

  Future<void> _restoreSession() async {
    _starting = true;
    try {
      await _restoreStoredSession();
      final grant = _takeGoogleRedirect?.call();
      if (_account == null && grant != null) {
        await _activate(await _client.exchangeGoogleCode(grant));
      }
    } finally {
      _starting = false;
    }
  }

  Future<void> _restoreStoredSession() async {
    final storage = _sessionStorage;
    if (storage == null) return;
    final saved = await storage.read();
    if (saved == null) return;
    SelfhostAuthSession session;
    try {
      session = await _client.restoreAccountSession(
        userId: saved.userId,
        refreshToken: saved.refreshToken,
      );
    } on SelfhostAuthFailure catch (error) {
      if (!error.sessionInvalid) rethrow;
      await storage.delete();
      return;
    }
    if (_disposed) return;
    await storage.write(
      StoredSelfhostAccountSession(
        userId: session.user.id,
        refreshToken: session.refreshToken,
      ),
    );
    if (_disposed) return;
    _account = session;
    _generation++;
    notifyListeners();
  }

  @override
  Future<void> signIn(String email, String password) => _mutate(() async {
    _requireGuest();
    await _activate(
      await _client.signInPassword(email: email, password: password),
    );
  });

  @override
  Future<void> create(String email, String password) =>
      createWithName(email, password);

  @override
  Future<void> createWithName(
    String email,
    String password, {
    String? displayName,
  }) => _mutate(() async {
    _requireGuest();
    final session = await _client.signUpEmail(
      email: email,
      password: password,
      displayName: displayName,
      redirectTo: _emailRedirect,
    );
    if (session == null) {
      // The existing form must stay open rather than celebrating a signed-in
      // account. The message is neutral for sanitized duplicate signups.
      throw const AppFailure(
        'email_confirmation_pending',
        'Account creation could not finish. Try signing in, or reset your password.',
      );
    }
    await _activate(session);
  });

  @override
  Future<void> signInGoogle() => _mutate(() async {
    _requireGuest();
    final redirect = _googleLoginRedirect;
    if (redirect != null) {
      await redirect();
      return;
    }
    await _activate(await _googleSession());
  }, prepareGoogle: _googleLoginRedirect == null);

  Future<SelfhostAuthSession> _googleSession({
    SelfhostAuthSession? link,
  }) async {
    final oauth = _googleOAuth;
    if (oauth != null) {
      return _client.exchangeGoogleCode(await oauth(link?.accessToken));
    }
    final google = _googleIdToken;
    if (google == null) {
      throw const AppFailure(
        'account_unavailable',
        'Google sign-in is unavailable here. You can use email instead.',
      );
    }
    final idToken = await google();
    if (_disposed) throw _accountChanged;
    return link == null
        ? _client.signInGoogle(idToken: idToken, nonce: _googleNonce?.call())
        : _client.linkGoogleToken(link, idToken, nonce: _googleNonce?.call());
  }

  SelfhostAuthSession _requireAccount() {
    final session = _account;
    if (session == null || _disposed || _signingOut) throw _accountChanged;
    return session;
  }

  Future<void> _activateOwner(SelfhostAuthSession session, String uid) async {
    if (_account?.user.id != uid || session.user.id != uid) {
      // A different Google selection must never select another private library.
      try {
        await _client.signOut(session);
      } catch (_) {}
      throw const AppFailure(
        'reauthentication_mismatch',
        'Choose the sign-in account already connected to this Unlabel account.',
      );
    }
    await _activate(session);
  }

  Future<SelfhostAuthSession> _reauthenticate([String? password]) async {
    final current = _requireAccount();
    final fresh =
        password != null && current.user.providers.contains('password')
        ? await _client.signInPassword(
            email: current.user.email!,
            password: password,
          )
        : await _googleSession();
    await _activateOwner(fresh, current.user.id);
    return fresh;
  }

  Future<void> _reloadOwner(SelfhostAuthSession session) async {
    await _activateOwner(await _client.refresh(session), session.user.id);
  }

  @override
  Future<void> linkGoogle() => _mutate(() async {
    final current = await _validAccountSession(_requireAccount());
    if (current.user.providers.contains('google.com')) throw _providerLinked;
    await _activateOwner(await _googleSession(link: current), current.user.id);
  }, prepareGoogle: true);

  @override
  Future<void> linkPassword(String email, String password) => _mutate(() async {
    final current = _requireAccount();
    if (current.user.providers.contains('password')) throw _providerLinked;
    if (email.trim().toLowerCase() != current.user.email?.toLowerCase()) {
      throw const AppFailure(
        'invalid_email',
        'Use the email address connected to this account.',
      );
    }
    // Adding the first password uses the verified current owner session. GoTrue
    // retains its own password-change/reauthentication policy; no popup is needed.
    final fresh = await _validAccountSession(current);
    await _client.updateUser(fresh, password: password);
    await _activateOwner(
      await _client.signInPassword(
        email: current.user.email!,
        password: password,
      ),
      current.user.id,
    );
  });

  @override
  Future<void> unlinkGoogle({required String password}) => _mutate(() async {
    final current = _requireAccount();
    if (!current.user.providers.contains('password')) {
      throw const AppFailure(
        'provider_required',
        'Add email and password before disconnecting Google.',
      );
    }
    final fresh = await _reauthenticate(password);
    final identities = await _client.identities(fresh);
    final google = identities.where((value) => value['provider'] == 'google');
    if (google.isEmpty) throw _accountChanged;
    await _client.unlinkIdentity(fresh, google.single['identity_id'] as String);
    await _reloadOwner(fresh);
  });

  @override
  Future<void> unlinkPassword() => _mutate(() async {
    final current = _requireAccount();
    if (!current.user.providers.contains('google.com')) {
      throw const AppFailure(
        'provider_required',
        'Connect Google before disconnecting email and password.',
      );
    }
    final fresh = await _reauthenticate();
    final identities = await _client.identities(fresh);
    final email = identities.where((value) => value['provider'] == 'email');
    if (email.isEmpty) throw _accountChanged;
    await _client.unlinkIdentity(fresh, email.single['identity_id'] as String);
    await _reloadOwner(fresh);
  }, prepareGoogle: true);

  @override
  Future<void> changeGoogleAccount({required String password}) => _mutate(
    () async {
      final current = _requireAccount();
      if (!current.user.providers.contains('password')) throw _accountChanged;
      final fresh = await _reauthenticate(password);
      // Link the replacement first. A collision/cancel keeps the old provider intact.
      final identities = await _client.identities(fresh);
      final old = identities
          .where((value) => value['provider'] == 'google')
          .toList();
      final linked = await _googleSession(link: fresh);
      await _activateOwner(linked, current.user.id);
      final after = await _client.identities(linked);
      if (!after.any(
        (value) =>
            value['provider'] == 'google' &&
            !old.any(
              (previous) => previous['identity_id'] == value['identity_id'],
            ),
      )) {
        throw const AppFailure(
          'provider_linked',
          'Choose a different Google account to replace this one.',
        );
      }
      for (final previous in old) {
        await _client.unlinkIdentity(linked, previous['identity_id'] as String);
      }
      await _reloadOwner(linked);
    },
    prepareGoogle: true,
  );

  @override
  Future<void> changeEmail(String email, String currentPassword) => _mutate(
    () async {
      final fresh = await _reauthenticate(currentPassword);
      await _client.updateUser(fresh, email: email, redirectTo: _emailRedirect);
      await _reloadOwner(fresh);
      if (_account?.user.email?.toLowerCase() != email.trim().toLowerCase()) {
        throw const AppFailure(
          'email_confirmation_pending',
          'Check your inbox to confirm the email change. Your current address still works until confirmation.',
        );
      }
    },
  );

  @override
  Future<void> changePassword(String currentPassword, String newPassword) =>
      _mutate(() async {
        final fresh = await _reauthenticate(currentPassword);
        await _client.updateUser(fresh, password: newPassword);
        await _reloadOwner(fresh);
      });

  @override
  Future<void> deleteAccount({
    String? password,
    required Future<void> Function(String uid, String token) deletePrivateData,
    required Future<void> Function() deleteLocalData,
  }) => _mutate(() async {
    final fresh = await _reauthenticate(password);
    await deletePrivateData(fresh.user.id, fresh.accessToken);
    await deleteLocalData();
    await _clearAccount();
  }, prepareGoogle: password == null);

  static const _providerLinked = AppFailure(
    'provider_linked',
    'This sign-in method is already connected to your account.',
  );

  @override
  Future<void> resetPassword(String email) => _mutate(
    () => _client.requestRecovery(
      email: email,
      redirectTo: _recoveryRedirect ?? _emailRedirect,
    ),
  );

  @override
  Future<void> signOut() => _mutate(() async {
    final current = _account;
    if (current == null) return;
    _signingOut = true;
    try {
      final session = await _validAccountSession(current);
      await _client.signOut(session);
    } on SelfhostAuthFailure catch (error) {
      if (!error.sessionInvalid) rethrow;
    } finally {
      _signingOut = false;
      await _clearAccount();
    }
  });

  @override
  Future<String> token(String expectedUid) async {
    final current = _account;
    if (_signingOut || current == null || current.user.id != expectedUid) {
      throw _accountChanged;
    }
    final session = await _validAccountSession(current);
    if (_disposed || _signingOut || _account != session) throw _accountChanged;
    return session.accessToken;
  }

  Future<SelfhostAuthSession> _validAccountSession(
    SelfhostAuthSession current,
  ) {
    if (!current.needsRefresh(_now())) return Future.value(current);
    final existing = _accountRefresh;
    if (existing != null) return existing;
    final generation = _generation;
    final refresh = _refreshAccount(current, generation);
    final operation = refresh.whenComplete(() {
      if (generation == _generation) _accountRefresh = null;
    });
    return _accountRefresh = operation;
  }

  Future<SelfhostAuthSession> _refreshAccount(
    SelfhostAuthSession current,
    int generation,
  ) async {
    try {
      final refreshed = await _client.refresh(current);
      if (_disposed || generation != _generation) throw _accountChanged;
      await _persist(refreshed);
      if (_disposed || generation != _generation) throw _accountChanged;
      _account = refreshed;
      return refreshed;
    } on SelfhostAuthFailure catch (error) {
      if (!_disposed && generation == _generation && error.sessionInvalid) {
        await _clearAccount();
      }
      rethrow;
    }
  }

  Future<String?> _scannerToken() async {
    if (_disposed || _busy) return null;
    final account = _account;
    if (account != null) return token(account.user.id);
    final generation = _generation;
    var guest = _guest;
    if (guest != null && guest.needsRefresh(_now())) {
      try {
        guest = await _client.refresh(guest);
      } on SelfhostAuthFailure catch (error) {
        if (!error.sessionInvalid) rethrow;
        if (_disposed || generation != _generation || _busy) return null;
        // Only definitive server expiry permits a replacement. A timeout or
        // 5xx keeps the existing credential and avoids account creation loops.
        guest = null;
        _guest = null;
      }
    }
    guest ??= await _client.signInGuest();
    if (_disposed || generation != _generation || _busy) return null;
    _guest = guest;
    return guest.accessToken;
  }

  Future<void> _mutate(
    Future<void> Function() operation, {
    bool prepareGoogle = false,
  }) async {
    if (_disposed) throw _accountChanged;
    if (_busy || _starting) {
      throw const AppFailure(
        'account_busy',
        'Wait for the current sign-in action to finish.',
      );
    }
    _busy = true;
    try {
      if (prepareGoogle) _prepareGoogleOAuth?.call();
      await operation();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const AppFailure(
          'account_cancelled',
          'Google sign-in was cancelled.',
        );
      }
      throw const AppFailure(
        'account_unavailable',
        'Google sign-in could not finish. Try again or use email.',
      );
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
        'account_unavailable',
        'Sign-in could not finish. Your local reports are still available.',
      );
    } finally {
      if (prepareGoogle) {
        try {
          _cancelGoogleOAuth?.call();
        } catch (_) {}
      }
      _busy = false;
    }
  }

  void _requireGuest() {
    if (_account != null) throw _accountChanged;
  }

  Future<void> _activate(SelfhostAuthSession session) async {
    if (_disposed || session.user.isAnonymous) throw _accountChanged;
    await _persist(session);
    if (_disposed) throw _accountChanged;
    _generation++;
    _accountRefresh = null;
    _account = session;
    notifyListeners();
  }

  Future<void> _persist(SelfhostAuthSession session) async {
    await _sessionStorage?.write(
      StoredSelfhostAccountSession(
        userId: session.user.id,
        refreshToken: session.refreshToken,
      ),
    );
  }

  Future<void> _clearAccount() async {
    if (_disposed) return;
    _generation++;
    final hadAccount = _account != null;
    _account = null;
    _accountRefresh = null;
    if (hadAccount) notifyListeners();
    await _sessionStorage?.delete();
  }

  static const _accountChanged = AppFailure(
    'account_changed',
    'Your sign-in session changed. Try again with the current account.',
  );

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _account = null;
    _guest = null;
    _accountRefresh = null;
    super.dispose();
  }
}
