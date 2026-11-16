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
    this._emailRedirect,
    this._sessionStorage,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final SelfhostAuthClient _client;
  final Future<String> Function()? _googleIdToken;
  final Uri? _emailRedirect;
  final SelfhostAccountSessionStorage? _sessionStorage;
  final DateTime Function() _now;
  late final ScannerAuth scannerAuth = SingleFlightScannerAuth(
    resolve: _scannerToken,
  );
  SelfhostAuthSession? _account;
  SelfhostAuthSession? _guest;
  Future<SelfhostAuthSession>? _accountRefresh;
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
            providers: user.providers,
          );
  }

  @override
  Future<void> start() async {
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
        'Check your inbox for a confirmation email, then sign in.',
      );
    }
    await _activate(session);
  });

  @override
  Future<void> signInGoogle() => _mutate(() async {
    _requireGuest();
    final google = _googleIdToken;
    if (google == null) {
      throw const AppFailure(
        'account_unavailable',
        'Google sign-in is unavailable here. You can use email instead.',
      );
    }
    final idToken = await google();
    if (_disposed) throw _accountChanged;
    await _activate(await _client.signInGoogle(idToken: idToken));
  });

  @override
  Future<void> resetPassword(String email) => _mutate(
    () => _client.requestRecovery(email: email, redirectTo: _emailRedirect),
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

  Future<void> _mutate(Future<void> Function() operation) async {
    if (_disposed) throw _accountChanged;
    if (_busy) {
      throw const AppFailure(
        'account_busy',
        'Wait for the current sign-in action to finish.',
      );
    }
    _busy = true;
    try {
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
