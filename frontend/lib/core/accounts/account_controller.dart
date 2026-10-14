import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_failure.dart';
import '../models/label_draft.dart';
import '../storage/local_store.dart';
import 'account_auth.dart';
import 'account_data.dart';
import 'account_store.dart';
import 'account_sync_api.dart';

enum AccountSyncState { guest, checking, ready, syncing, needsChoice, failed }

class AccountController extends ChangeNotifier {
  AccountController({
    required this.auth,
    required this.api,
    required this.guestStore,
    PreferencesAdapter? preferences,
    this.debounce = const Duration(seconds: 2),
  }) : _preferences = preferences ?? AsyncPreferencesAdapter();
  final AccountAuth auth;
  final AccountSyncTransport api;
  final LocalStore guestStore;
  final PreferencesAdapter _preferences;
  final Duration debounce;
  AccountStore? _store;
  AccountIdentity? _identity;
  AccountIdentity? get identity => _identity;
  LocalStore get activeStore => _store ?? guestStore;
  AccountStore? get accountStore => _store;
  AccountSyncState state = AccountSyncState.guest;
  String message = 'Your history and saved products stay on this device.';
  bool authBusy = false;
  AccountData? localData;
  AccountSnapshot? _remote;
  int? _choiceLocalRevision;
  int _generation = 0;
  Timer? _timer;
  Future<void>? _syncing;
  bool _disposed = false;
  bool _started = false;
  String? _deletionPendingUid;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    auth.addListener(_authChanged);
    try {
      await auth.start();
      _authChanged();
    } on AppFailure catch (error) {
      _fail(error);
    } catch (_) {
      _fail(
        const AppFailure(
          'account_unavailable',
          'Sign-in could not be restored. Continue as a guest.',
        ),
      );
    }
  }

  void _publish() {
    if (!_disposed) notifyListeners();
  }

  bool _current(int generation, String uid) =>
      !_disposed &&
      generation == _generation &&
      _identity?.uid == uid &&
      auth.identity?.uid == uid;
  void _authChanged() {
    if (_disposed) return;
    final next = auth.identity;
    if (next?.uid == _identity?.uid) {
      // Linking a provider or refreshing SDK profile metadata keeps the same
      // private library, in-flight sync and explicit cloud/device choice.
      if (next != null) {
        _identity = next;
        _publish();
      }
      return;
    }
    _generation++;
    _timer?.cancel();
    api.cancelAll();
    _store?.onChanged = null;
    _syncing = null;
    _remote = null;
    _choiceLocalRevision = null;
    _deletionPendingUid = null;
    localData = null;
    _identity = auth.identity;
    if (_identity == null) {
      _store = null;
      state = AccountSyncState.guest;
      message = 'Your history and saved products stay on this device.';
    } else {
      _store = AccountStore(uid: _identity!.uid, preferences: _preferences)
        ..onChanged = _localChanged;
      state = AccountSyncState.checking;
      message = 'Checking your private account library…';
      unawaited(refreshSync());
    }
    _publish();
  }

  void _localChanged() {
    if (_disposed || _store == null) return;
    unawaited(_readLocal());
    if (_deletionPendingUid == _identity?.uid) return;
    if (state == AccountSyncState.needsChoice) return;
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(refreshSync()));
  }

  Future<void> _readLocal() async {
    final store = _store;
    if (store == null) return;
    try {
      final cache = await store.snapshot();
      if (identical(store, _store)) {
        localData = cache.data;
        _publish();
      }
    } on AppFailure catch (error) {
      if (identical(store, _store)) _fail(error);
    }
  }

  Future<void> _authenticate(Future<void> Function() operation) async {
    if (authBusy) return;
    authBusy = true;
    _publish();
    try {
      await operation();
      _authChanged();
    } finally {
      authBusy = false;
      _publish();
    }
  }

  Future<void> signIn(String email, String password) =>
      _authenticate(() => auth.signIn(email, password));
  Future<void> signInGoogle() => _authenticate(auth.signInGoogle);
  Future<void> create(String email, String password, {String? displayName}) =>
      _authenticate(
        () => auth.createWithName(email, password, displayName: displayName),
      );
  Future<void> linkGoogle() => _authenticate(auth.linkGoogle);
  Future<void> linkPassword(String email, String password) =>
      _authenticate(() => auth.linkPassword(email, password));
  Future<void> unlinkGoogle({required String password}) =>
      _authenticate(() => auth.unlinkGoogle(password: password));
  Future<void> unlinkPassword() => _authenticate(auth.unlinkPassword);
  Future<void> changeGoogleAccount({required String password}) =>
      _authenticate(() => auth.changeGoogleAccount(password: password));
  Future<void> changeEmail(String email, String currentPassword) =>
      _authenticate(() => auth.changeEmail(email, currentPassword));
  Future<void> changePassword(String currentPassword, String newPassword) =>
      _authenticate(() => auth.changePassword(currentPassword, newPassword));
  Future<void> deleteAccount({String? password}) async {
    final store = _store;
    final uid = _identity?.uid;
    final deletion = api;
    if (store == null || uid == null) {
      throw const AppFailure(
        'account_changed',
        'Sign in before deleting an account.',
      );
    }
    if (deletion is! AccountDeletionTransport) {
      throw const AppFailure(
        'account_delete_unavailable',
        'Account deletion could not connect. Please try again later.',
      );
    }
    final deleteTransport = deletion as AccountDeletionTransport;
    if (authBusy) {
      throw const AppFailure(
        'account_busy',
        'Wait for the current account action to finish.',
      );
    }
    _generation++;
    _timer?.cancel();
    api.cancelAll();
    store.onChanged = null;
    _syncing = null;
    try {
      await _authenticate(
        () => auth.deleteAccount(
          password: password,
          deletePrivateData: (owner, token) async {
            if (owner != uid || auth.identity?.uid != uid) {
              throw const AppFailure(
                'account_changed',
                'Your account changed. No other account was deleted.',
              );
            }
            // A timed-out response can still have admitted cloud deletion.
            // Keep this owner read-only until deletion is retried or the SDK
            // session changes, rather than recreating the private library.
            _deletionPendingUid = uid;
            store.markDeletionPending();
            _remote = null;
            _choiceLocalRevision = null;
            await deleteTransport.deletePrivateAccount(token);
          },
          deleteLocalData: store.deleteNamespace,
        ),
      );
    } on AppFailure catch (error) {
      if (identical(store, _store) && _identity?.uid == uid) _fail(error);
      rethrow;
    } finally {
      if (identical(store, _store) && _identity?.uid == uid) {
        // A failed deletion retains local data. Do not automatically re-upload
        // it into a private account that is already marked for deletion.
        _syncing = null;
        store.onChanged = _localChanged;
      }
    }
  }

  Future<void> resetPassword(String email) =>
      _authenticate(() => auth.resetPassword(email));
  Future<void> signOut() async {
    _generation++;
    _timer?.cancel();
    api.cancelAll();
    _store?.onChanged = null;
    try {
      await _authenticate(auth.signOut);
    } finally {
      // A failed SDK sign-out must not silently claim the account was signed out.
      if (auth.identity != null) {
        _store?.onChanged = _localChanged;
        _syncing = null;
      }
    }
  }

  Future<void> refreshSync() {
    if (_store == null || _identity == null) return Future.value();
    if (_deletionPendingUid == _identity?.uid) {
      return Future.error(
        const AppFailure(
          'account_delete_incomplete',
          'Account deletion is unfinished. Retry deleting the account before changing its private library.',
        ),
      );
    }
    final existing = _syncing;
    if (existing != null) return existing;
    late final Future<void> operation;
    operation = _refresh().whenComplete(() {
      if (identical(_syncing, operation)) _syncing = null;
    });
    _syncing = operation;
    return operation;
  }

  void _requireLibraryWritable() {
    if (_deletionPendingUid == _identity?.uid && _identity != null) {
      throw const AppFailure(
        'account_delete_incomplete',
        'Account deletion is unfinished. Retry deleting the account before changing its private library.',
      );
    }
  }

  Future<void> _refresh() async {
    final store = _store!;
    final uid = _identity!.uid;
    final generation = _generation;
    state = AccountSyncState.checking;
    message = 'Checking your private account library…';
    _publish();
    try {
      final before = await store.snapshot();
      if (!_current(generation, uid)) return;
      localData = before.data;
      if (!await api.available()) {
        throw const AppFailure(
          'sync_unavailable',
          'Private sync is unavailable right now. Your account library stays on this device.',
        );
      }
      if (!_current(generation, uid)) return;
      final token = await auth.token(uid);
      if (!_current(generation, uid)) return;
      final cloud = await api.fetch(token);
      if (!_current(generation, uid)) return;
      final cache = await store.snapshot();
      if (!_current(generation, uid)) return;
      localData = cache.data;
      if (cache.pending != null &&
          cloud.revision == cache.pending!.expectedRevision &&
          !cloud.data.sameContent(cache.pending!.data)) {
        // Resolve an uncertain older write before acknowledging newer local edits.
        await _uploadIfDirty(store, generation, uid);
      } else if (cloud.data.sameContent(cache.data)) {
        await store.acceptCloud(
          cloud,
          expectedLocalRevision: cache.localRevision,
        );
        if (!_current(generation, uid)) return;
        localData = cloud.data;
        _ready('Your account library is synced.');
      } else if (cache.pending != null &&
          cloud.data.sameContent(cache.pending!.data)) {
        await store.acceptUpload(cloud, cache.pending!.id);
        await _uploadIfDirty(store, generation, uid);
      } else if (cache.dirty && cache.cloudRevision == cloud.revision) {
        await _uploadIfDirty(store, generation, uid);
      } else if (cache.cloudRevision == null &&
          cache.data.isEmpty &&
          cloud.revision == 0) {
        await store.acceptCloud(
          cloud,
          expectedLocalRevision: cache.localRevision,
        );
        if (!_current(generation, uid)) return;
        localData = cloud.data;
        _ready('New saved products and history will sync privately.');
      } else {
        _remote = cloud;
        _choiceLocalRevision = cache.localRevision;
        state = AccountSyncState.needsChoice;
        message = 'This device and cloud have different account libraries. Choose which to keep; nothing was merged or replaced.';
        _publish();
      }
    } on AppFailure catch (error) {
      if (_current(generation, uid)) _fail(error);
    } catch (_) {
      if (_current(generation, uid)) {
        _fail(
          const AppFailure(
            'sync_unavailable',
            'Sync could not finish. Your device data is safe.',
          ),
        );
      }
    }
  }

  Future<void> _uploadIfDirty(
    AccountStore store,
    int generation,
    String uid,
  ) async {
    final cache = await store.snapshot();
    if (!_current(generation, uid)) return;
    if (!cache.dirty && cache.pending == null) {
      _ready('Your account library is synced.');
      return;
    }
    final mutation = await store.prepareMutation();
    if (!_current(generation, uid)) return;
    state = AccountSyncState.syncing;
    message = 'Saving your private account library…';
    _publish();
    final token = await auth.token(uid);
    if (!_current(generation, uid)) return;
    try {
      final cloud = await api.put(token, mutation);
      if (!_current(generation, uid)) return;
      if (!cloud.data.sameContent(mutation.data)) {
        throw const AppFailure(
          'invalid_response',
          'Sync did not confirm the submitted library. Check sync again.',
        );
      }
      await store.acceptUpload(cloud, mutation.id);
      final now = await store.snapshot();
      if (!_current(generation, uid)) return;
      localData = now.data;
      _ready(
        now.dirty
            ? 'More device changes are waiting to sync.'
            : 'Your account library is synced.',
      );
      if (now.dirty) _localChanged();
    } on AppFailure catch (error) {
      if (!_current(generation, uid)) return;
      if (error.kind == 'sync_invalid') await store.discardPending(mutation.id);
      if (error.kind == 'sync_conflict') {
        final cloud = await api.fetch(token);
        if (!_current(generation, uid)) return;
        final latest = await store.snapshot();
        if (!_current(generation, uid)) return;
        _remote = cloud;
        _choiceLocalRevision = latest.localRevision;
        localData = latest.data;
        state = AccountSyncState.needsChoice;
        message = 'Cloud data changed while saving. Choose which account library to keep; your device changes are safe.';
        _publish();
        return;
      }
      rethrow;
    }
  }

  void _ready(String text) {
    state = AccountSyncState.ready;
    message = text;
    _remote = null;
    _choiceLocalRevision = null;
    _publish();
  }

  void _fail(AppFailure error) {
    state = AccountSyncState.failed;
    message = error.userMessage;
    _publish();
  }

  Future<void> useCloud() async {
    _requireLibraryWritable();
    final store = _store;
    final cloud = _remote;
    final expected = _choiceLocalRevision;
    if (store == null || cloud == null || expected == null) return;
    await store.acceptCloud(cloud, expectedLocalRevision: expected);
    if (!identical(store, _store)) return;
    localData = cloud.data;
    _ready('Your cloud library is now on this device.');
  }

  Future<void> useDevice() async {
    _requireLibraryWritable();
    final store = _store;
    final cloud = _remote;
    final expected = _choiceLocalRevision;
    if (store == null || cloud == null || expected == null) return;
    await store.keepLocalAt(cloud.revision, expectedLocalRevision: expected);
    if (!identical(store, _store)) return;
    _remote = null;
    _choiceLocalRevision = null;
    await refreshSync();
  }

  Future<void> updateDisplayName(String value) async {
    _requireLibraryWritable();
    final store = _store;
    if (store == null) return;
    await store.setDisplayName(value);
    await _readLocal();
  }

  Future<void> copyGuestLibrary() async {
    _requireLibraryWritable();
    final store = _store;
    if (store == null) return;
    if (state != AccountSyncState.ready) {
      throw const AppFailure(
        'sync_choice',
        'Finish checking or resolving account sync before copying guest reports.',
      );
    }
    final cache = await store.snapshot();
    if (!cache.data.isEmpty) {
      throw const AppFailure(
        'sync_choice',
        'The account library already has data. Keep it or explicitly clear it before copying guest reports.',
      );
    }
    final saved = await guestStore.saved();
    final history = await guestStore.history();
    if (!identical(store, _store)) {
      throw const AppFailure(
        'account_changed',
        'Sign-in changed. No guest reports were copied.',
      );
    }
    AccountEntry entry(LocalReport value) => AccountEntry(
      entryId: newSubmissionId(),
      recordedAt: value.storedAt,
      report: value.report,
    );
    final data = AccountData(
      saved: saved.map(entry).toList(),
      history: history.map(entry).toList(),
    )..checkSyncSize();
    await store.copyIntoEmpty(data, expectedLocalRevision: cache.localRevision);
    await _readLocal();
  }

  Future<void> clearAccountLibrary() async {
    _requireLibraryWritable();
    final store = _store;
    if (store == null) return;
    if (state == AccountSyncState.needsChoice ||
        state == AccountSyncState.checking ||
        state == AccountSyncState.syncing) {
      throw const AppFailure(
        'sync_choice',
        'Finish checking or resolving sync before clearing account data.',
      );
    }
    await store.replaceLocal(AccountData());
    await refreshSync();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    _store?.onChanged = null;
    auth.removeListener(_authChanged);
    api.cancelAll();
    super.dispose();
  }
}
