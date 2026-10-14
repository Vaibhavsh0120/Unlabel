import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:unlabel/core/accounts/account_auth.dart';
import 'package:unlabel/core/accounts/account_controller.dart';
import 'package:unlabel/core/accounts/account_data.dart';
import 'package:unlabel/core/accounts/account_sync_api.dart';
import 'package:unlabel/core/models/app_failure.dart';
import 'package:unlabel/core/storage/local_store.dart';

class _Provider implements UserInfo {
  _Provider(this.providerId, {this.displayName, this.photoURL, this.email});
  @override
  final String providerId;
  @override
  final String? displayName;
  @override
  final String? photoURL;
  @override
  final String? email;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Credential implements UserCredential {
  _Credential(this.user);
  @override
  final User user;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements User {
  _User({
    this.uid = 'synthetic-owner-a',
    this.isAnonymous = false,
    this.displayName,
    this.photoURL,
    List<String> providers = const ['password'],
  }) : providerData = providers.map(_Provider.new).toList();

  @override
  final String uid;
  @override
  bool isAnonymous;
  @override
  final String? email = 'synthetic@example.invalid';
  @override
  String? displayName;
  @override
  final String? photoURL;
  @override
  final List<UserInfo> providerData;
  int links = 0;
  String? linkFailure;
  bool failProfile = false;
  User? unexpectedLinkedUser;
  int reloads = 0, reauths = 0, unlinks = 0, deletes = 0;
  String? reauthFailure, unlinkFailure, deleteFailure, lastReauthProvider;
  Completer<void>? reauthWait, deleteWait;
  void Function()? onDelete, onReload;
  UserInfo? replacementGoogle;
  final accountEvents = <String>[];
  String? verifiedNewEmail, updatedPassword;
  String? credentialChangeFailure;

  @override
  Future<UserCredential> linkWithCredential(AuthCredential credential) async {
    links++;
    if (linkFailure != null) throw FirebaseAuthException(code: linkFailure!);
    providerData.add(
      credential.providerId == 'google.com' && replacementGoogle != null
          ? replacementGoogle!
          : _Provider(credential.providerId),
    );
    isAnonymous = false;
    return _Credential(unexpectedLinkedUser ?? this);
  }

  @override
  Future<void> updateDisplayName(String? value) async {
    if (failProfile) {
      throw FirebaseAuthException(code: 'network-request-failed');
    }
    displayName = value;
  }

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async =>
      'synthetic-token-$uid';

  @override
  Future<void> reload() async {
    accountEvents.add('reload');
    reloads++;
    onReload?.call();
  }

  @override
  Future<UserCredential> reauthenticateWithCredential(
    AuthCredential credential,
  ) async {
    accountEvents.add('reauthenticate');
    reauths++;
    lastReauthProvider = credential.providerId;
    if (reauthWait != null) await reauthWait!.future;
    if (reauthFailure != null) {
      throw FirebaseAuthException(code: reauthFailure!);
    }
    return _Credential(this);
  }

  @override
  Future<void> verifyBeforeUpdateEmail(
    String newEmail, [
    ActionCodeSettings? actionCodeSettings,
  ]) async {
    accountEvents.add('verify-email');
    if (credentialChangeFailure != null) {
      throw FirebaseAuthException(code: credentialChangeFailure!);
    }
    verifiedNewEmail = newEmail;
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    accountEvents.add('update-password');
    if (credentialChangeFailure != null) {
      throw FirebaseAuthException(code: credentialChangeFailure!);
    }
    updatedPassword = newPassword;
  }

  @override
  Future<User> unlink(String providerId) async {
    unlinks++;
    if (unlinkFailure != null) {
      throw FirebaseAuthException(code: unlinkFailure!);
    }
    providerData.removeWhere((value) => value.providerId == providerId);
    return this;
  }

  @override
  Future<void> delete() async {
    deletes++;
    if (deleteWait != null) await deleteWait!.future;
    if (deleteFailure != null) {
      throw FirebaseAuthException(code: deleteFailure!);
    }
    onDelete?.call();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Firebase implements FirebaseAuth {
  _Firebase([this.currentUser]) {
    _attachDelete();
  }
  @override
  User? currentUser;
  final changes = StreamController<User?>.broadcast();
  int googleSignIns = 0;
  int passwordSignIns = 0;
  int creates = 0;
  int resets = 0;
  String? resetEmail;
  ActionCodeSettings? resetSettings;
  Completer<void>? resetWait;
  _User googleResult = _User(
    displayName: 'Synthetic Google Name',
    photoURL: 'https://example.invalid/synthetic-avatar.png',
    providers: ['google.com'],
  );
  _User passwordResult = _User();
  String? resetFailure;

  void _attachDelete() {
    final user = currentUser;
    if (user is _User) {
      user.onDelete = () {
        if (currentUser?.uid == user.uid) {
          currentUser = null;
          changes.add(null);
        }
      };
    }
  }

  @override
  Stream<User?> authStateChanges() async* {
    yield currentUser;
    yield* changes.stream;
  }

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    googleSignIns++;
    currentUser = googleResult;
    _attachDelete();
    changes.add(currentUser);
    return _Credential(currentUser!);
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    passwordSignIns++;
    currentUser = passwordResult;
    _attachDelete();
    changes.add(currentUser);
    return _Credential(currentUser!);
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    creates++;
    currentUser = passwordResult;
    _attachDelete();
    changes.add(currentUser);
    return _Credential(currentUser!);
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    resets++;
    resetEmail = email;
    resetSettings = actionCodeSettings;
    if (resetWait != null) await resetWait!.future;
    if (resetFailure != null) throw FirebaseAuthException(code: resetFailure!);
  }

  @override
  Future<void> signOut() async {
    currentUser = null;
    changes.add(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _options = FirebaseOptions(
  apiKey: 'synthetic-not-a-key',
  appId: 'synthetic-app',
  messagingSenderId: 'synthetic-sender',
  projectId: 'synthetic-project',
);

FirebaseAccountAuth _auth(
  _Firebase firebase, {
  Future<AuthCredential> Function()? credential,
}) => FirebaseAccountAuth(
  options: _options,
  firebaseAuth: firebase,
  googleCredential:
      credential ??
      () async => GoogleAuthProvider.credential(idToken: 'synthetic-id-token'),
  googleSignOut: () async {},
);

Matcher _failure(String kind) =>
    isA<AppFailure>().having((error) => error.kind, 'kind', kind);

class _Preferences implements PreferencesAdapter {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
}

class _Sync implements AccountSyncTransport {
  AccountSnapshot cloud = AccountSnapshot(
    revision: 1,
    data: AccountData(displayName: 'Existing cloud name'),
  );
  int cancellations = 0;
  int writes = 0;
  @override
  Future<bool> available() async => true;
  @override
  Future<AccountSnapshot> fetch(String token) async => cloud;
  @override
  Future<AccountSnapshot> put(String token, AccountMutation mutation) async {
    writes++;
    return cloud;
  }

  @override
  void cancelAll() => cancellations++;
  @override
  void close() {}
}

class _DeletionSync extends _Sync implements AccountDeletionTransport {
  int deleted = 0;
  AppFailure? deleteFailure;
  Completer<void>? deleteWait;
  @override
  Future<void> deletePrivateAccount(String token) async {
    deleted++;
    if (deleteWait != null) await deleteWait!.future;
    if (deleteFailure != null) throw deleteFailure!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'email change verifies the new address after password reauthentication',
    () async {
      final user = _User(providers: ['google.com', 'password']);
      final auth = _auth(_Firebase(user));
      addTearDown(auth.dispose);
      await auth.changeEmail(
        '  replacement@example.invalid  ',
        'Synthetic123!',
      );
      expect(user.accountEvents, ['reload', 'reauthenticate', 'verify-email']);
      expect(user.lastReauthProvider, 'password');
      expect(user.verifiedNewEmail, 'replacement@example.invalid');
      expect(auth.identity?.email, 'synthetic@example.invalid');
      expect(auth.identity?.uid, user.uid);
      expect(auth.identity?.providers, {'google.com', 'password'});
    },
  );

  test(
    'password change reauthenticates and retains both linked providers',
    () async {
      final user = _User(providers: ['google.com', 'password']);
      final auth = _auth(_Firebase(user));
      addTearDown(auth.dispose);
      await auth.changePassword('Synthetic123!', 'Replacement456!');
      expect(user.accountEvents, [
        'reload',
        'reauthenticate',
        'update-password',
      ]);
      expect(user.lastReauthProvider, 'password');
      expect(user.updatedPassword, 'Replacement456!');
      expect(auth.identity?.uid, user.uid);
      expect(auth.identity?.providers, {'google.com', 'password'});
    },
  );

  test('failed reauthentication prevents email and password changes', () async {
    for (final emailChange in [true, false]) {
      final user = _User()..reauthFailure = 'wrong-password';
      final auth = _auth(_Firebase(user));
      try {
        await expectLater(
          emailChange
              ? auth.changeEmail(
                  'replacement@example.invalid',
                  'WrongPassword1',
                )
              : auth.changePassword('WrongPassword1', 'Replacement456!'),
          throwsA(_failure('invalid_credentials')),
        );
        expect(user.accountEvents, ['reload', 'reauthenticate']);
        expect(user.verifiedNewEmail, isNull);
        expect(user.updatedPassword, isNull);
      } finally {
        auth.dispose();
      }
    }
  });

  test(
    'owner changes during reauthentication prevent credential mutation',
    () async {
      for (final emailChange in [true, false]) {
        final user = _User()..reauthWait = Completer<void>();
        final firebase = _Firebase(user);
        final auth = _auth(firebase);
        try {
          await auth.start();
          final pending = emailChange
              ? auth.changeEmail('replacement@example.invalid', 'Synthetic123!')
              : auth.changePassword('Synthetic123!', 'Replacement456!');
          await Future<void>.delayed(Duration.zero);
          firebase.currentUser = _User(uid: 'synthetic-owner-b');
          firebase.changes.add(firebase.currentUser);
          user.reauthWait!.complete();
          await expectLater(pending, throwsA(_failure('account_changed')));
          expect(user.verifiedNewEmail, isNull);
          expect(user.updatedPassword, isNull);
          expect(auth.identity?.uid, 'synthetic-owner-b');
        } finally {
          auth.dispose();
        }
      }
    },
  );

  test(
    'a refreshed missing password provider cannot change credentials',
    () async {
      for (final emailChange in [true, false]) {
        final user = _User(providers: ['google.com', 'password']);
        user.onReload = () => user.providerData.removeWhere(
          (provider) => provider.providerId == 'password',
        );
        final auth = _auth(_Firebase(user));
        try {
          await expectLater(
            emailChange
                ? auth.changeEmail(
                    'replacement@example.invalid',
                    'Synthetic123!',
                  )
                : auth.changePassword('Synthetic123!', 'Replacement456!'),
            throwsA(_failure('provider_not_linked')),
          );
          expect(user.reauths, 0);
          expect(user.verifiedNewEmail, isNull);
          expect(user.updatedPassword, isNull);
        } finally {
          auth.dispose();
        }
      }
    },
  );

  test(
    'SDK credential-change failures are surfaced without claiming success',
    () async {
      for (final emailChange in [true, false]) {
        final user = _User()..credentialChangeFailure = 'requires-recent-login';
        final auth = _auth(_Firebase(user));
        try {
          await expectLater(
            emailChange
                ? auth.changeEmail(
                    'replacement@example.invalid',
                    'Synthetic123!',
                  )
                : auth.changePassword('Synthetic123!', 'Replacement456!'),
            throwsA(_failure('reauthentication_required')),
          );
          expect(user.verifiedNewEmail, isNull);
          expect(user.updatedPassword, isNull);
          expect(auth.identity?.uid, user.uid);
        } finally {
          auth.dispose();
        }
      }
    },
  );

  test('failed private deletion keeps its namespace read-only until explicit retry', () async {
    final firebase = _Firebase(_User());
    final auth = _auth(firebase);
    final prefs = _Preferences();
    final sync = _DeletionSync()
      ..deleteFailure = const AppFailure(
        'sync_network',
        'Synthetic uncertain cleanup.',
      );
    final controller = AccountController(
      auth: auth,
      api: sync,
      guestStore: LocalStore(preferences: prefs),
      preferences: prefs,
      debounce: const Duration(days: 1),
    );
    addTearDown(controller.dispose);
    addTearDown(auth.dispose);
    await controller.start();
    await controller.refreshSync();
    await controller.updateDisplayName('Keep this device copy');
    final store = controller.accountStore!;
    final before = await store.snapshot();
    await expectLater(
      controller.deleteAccount(password: 'Synthetic123!'),
      throwsA(_failure('sync_network')),
    );
    expect(identical(store, controller.accountStore), isTrue);
    expect(controller.identity?.uid, 'synthetic-owner-a');
    final writes = sync.writes;
    for (final action in <Future<void> Function()>[
      controller.refreshSync,
      () => controller.updateDisplayName('Do not replace me'),
      controller.clearAccountLibrary,
      controller.copyGuestLibrary,
      controller.useCloud,
      controller.useDevice,
      () => store.setDisplayName('Late retained-store write'),
    ]) {
      await expectLater(
        action(),
        throwsA(_failure('account_delete_incomplete')),
      );
    }
    expect((await store.snapshot()).data.sameContent(before.data), isTrue);
    expect(sync.writes, writes);
    sync.deleteFailure = null;
    await controller.deleteAccount(password: 'Synthetic123!');
    expect(sync.deleted, 2);
    expect(prefs.values.containsKey(store.key), isFalse);
    expect(controller.identity, isNull);
  });

  test('failed deletion identity proof leaves the library editable', () async {
    final user = _User()..reauthFailure = 'wrong-password';
    final auth = _auth(_Firebase(user));
    final prefs = _Preferences();
    final sync = _DeletionSync();
    final controller = AccountController(
      auth: auth,
      api: sync,
      guestStore: LocalStore(preferences: prefs),
      preferences: prefs,
      debounce: const Duration(days: 1),
    );
    addTearDown(controller.dispose);
    addTearDown(auth.dispose);
    await controller.start();
    await controller.refreshSync();
    await expectLater(
      controller.deleteAccount(password: 'WrongPassword1'),
      throwsA(_failure('invalid_credentials')),
    );
    expect(sync.deleted, 0);
    await controller.updateDisplayName('Still editable');
    expect(
      (await controller.accountStore!.snapshot()).data.displayName,
      'Still editable',
    );
  });

  testWidgets(
    'timed-out private deletion cannot re-upload or edit its retained namespace',
    (tester) async {
      final firebase = _Firebase(_User());
      final auth = _auth(firebase);
      final prefs = _Preferences();
      final sync = _DeletionSync()..deleteWait = Completer<void>();
      final controller = AccountController(
        auth: auth,
        api: sync,
        guestStore: LocalStore(preferences: prefs),
        preferences: prefs,
        debounce: const Duration(days: 1),
      );
      addTearDown(controller.dispose);
      addTearDown(auth.dispose);
      await controller.start();
      await controller.refreshSync();
      await controller.updateDisplayName('Pending private deletion');
      final store = controller.accountStore!;
      final pending = controller.deleteAccount(password: 'Synthetic123!');
      final timedOut = expectLater(
        pending,
        throwsA(_failure('account_unavailable')),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 16));
      await timedOut;
      await expectLater(
        controller.refreshSync(),
        throwsA(_failure('account_delete_incomplete')),
      );
      await expectLater(
        store.setDisplayName('Late write'),
        throwsA(_failure('account_delete_incomplete')),
      );
      expect(sync.writes, 0);
      expect(prefs.values.containsKey(store.key), isTrue);
      sync.deleteWait!.complete();
      await tester.pump();
      expect(controller.identity, isNull);
      expect(prefs.values.containsKey(store.key), isFalse);
    },
  );

  test('the last supported provider cannot be removed or switched', () async {
    for (final provider in ['google.com', 'password']) {
      final user = _User(providers: [provider]);
      final auth = _auth(_Firebase(user));
      final action = provider == 'google.com'
          ? auth.unlinkGoogle(password: 'Synthetic123!')
          : auth.unlinkPassword();
      await expectLater(action, throwsA(_failure('last_sign_in_method')));
      if (provider == 'google.com') {
        await expectLater(
          auth.changeGoogleAccount(password: 'Synthetic123!'),
          throwsA(_failure('last_sign_in_method')),
        );
      }
      expect(user.reauths, 0);
      expect(user.unlinks, 0);
      auth.dispose();
    }
  });

  test(
    'Google unlink proves password backup and removes stale Google image',
    () async {
      final user = _User(
        providers: ['google.com', 'password'],
        photoURL: 'https://example.invalid/old-google.png',
      );
      final auth = _auth(_Firebase(user));
      addTearDown(auth.dispose);
      await auth.unlinkGoogle(password: 'Synthetic123!');
      expect(user.lastReauthProvider, 'password');
      expect(auth.identity?.providers, {'password'});
      expect(auth.identity?.uid, user.uid);
      expect(auth.identity?.photoUrl, isNull);
    },
  );

  test(
    'password unlink proves remaining Google access without switching UID',
    () async {
      final user = _User(providers: ['google.com', 'password']);
      final firebase = _Firebase(user);
      final auth = _auth(firebase);
      addTearDown(auth.dispose);
      await auth.unlinkPassword();
      expect(user.lastReauthProvider, 'google.com');
      expect(auth.identity?.providers, {'google.com'});
      expect(auth.identity?.uid, user.uid);
      expect(firebase.googleSignIns, 0);
    },
  );

  test(
    'wrong password or cancelled Google proof cannot unlink a provider',
    () async {
      final user = _User(providers: ['google.com', 'password'])
        ..reauthFailure = 'wrong-password';
      final auth = _auth(_Firebase(user));
      addTearDown(auth.dispose);
      await expectLater(
        auth.unlinkGoogle(password: 'WrongSynthetic1'),
        throwsA(_failure('invalid_credentials')),
      );
      expect(user.unlinks, 0);
      final cancelled = _auth(
        _Firebase(_User(providers: ['google.com', 'password'])),
        credential: () async => throw const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
        ),
      );
      addTearDown(cancelled.dispose);
      await expectLater(
        cancelled.unlinkPassword(),
        throwsA(_failure('account_cancelled')),
      );
      expect(cancelled.identity?.providers, {'google.com', 'password'});
    },
  );

  test('provider reload catches a backup removed on another device', () async {
    final user = _User(providers: ['google.com', 'password']);
    user.onReload = () => user.providerData.removeWhere(
      (provider) => provider.providerId == 'password',
    );
    final auth = _auth(_Firebase(user));
    addTearDown(auth.dispose);
    await expectLater(
      auth.unlinkGoogle(password: 'Synthetic123!'),
      throwsA(_failure('last_sign_in_method')),
    );
    expect(user.unlinks, 0);
    expect(user.reauths, 0);
  });

  test('owner changing during reauthentication stops unlink', () async {
    final user = _User(providers: ['google.com', 'password'])
      ..reauthWait = Completer<void>();
    final firebase = _Firebase(user);
    final auth = _auth(firebase);
    addTearDown(auth.dispose);
    await auth.start();
    final pending = auth.unlinkGoogle(password: 'Synthetic123!');
    await Future<void>.delayed(Duration.zero);
    firebase.currentUser = _User(uid: 'synthetic-owner-b');
    firebase.changes.add(firebase.currentUser);
    user.reauthWait!.complete();
    await expectLater(pending, throwsA(_failure('account_changed')));
    expect(user.unlinks, 0);
  });

  test(
    'Google replacement refreshes provider name/photo on the same UID',
    () async {
      final user =
          _User(
              providers: ['google.com', 'password'],
              displayName: 'Old Google Name',
              photoURL: 'https://example.invalid/old-google.png',
            )
            ..replacementGoogle = _Provider(
              'google.com',
              email: 'replacement@example.invalid',
              displayName: 'Replacement Google Name',
              photoURL: 'https://example.invalid/replacement-google.png',
            );
      final firebase = _Firebase(user);
      final auth = _auth(firebase);
      addTearDown(auth.dispose);
      await auth.changeGoogleAccount(password: 'Synthetic123!');
      expect(auth.identity?.uid, user.uid);
      expect(auth.identity?.providers, {'password', 'google.com'});
      expect(auth.identity?.displayName, 'Replacement Google Name');
      expect(auth.identity?.googleEmail, 'replacement@example.invalid');
      expect(
        auth.identity?.photoUrl,
        'https://example.invalid/replacement-google.png',
      );
      expect(firebase.googleSignIns, 0);
    },
  );

  test(
    'replacement cancellation and collision retain password and UID',
    () async {
      for (final collision in [false, true]) {
        final user = _User(providers: ['google.com', 'password']);
        if (collision) user.linkFailure = 'credential-already-in-use';
        final firebase = _Firebase(user);
        final auth = _auth(
          firebase,
          credential: collision
              ? null
              : () async => throw const GoogleSignInException(
                  code: GoogleSignInExceptionCode.canceled,
                ),
        );
        await expectLater(
          auth.changeGoogleAccount(password: 'Synthetic123!'),
          throwsA(_failure('google_change_incomplete')),
        );
        expect(auth.identity?.uid, user.uid);
        expect(auth.identity?.providers, {'password'});
        expect(firebase.googleSignIns, 0);
        auth.dispose();
      }
    },
  );

  test('deletion reauthenticates then clears private data, Auth and local data in order', () async {
    final user = _User(providers: ['google.com']);
    final firebase = _Firebase(user);
    final events = <String>[];
    final original = user.onDelete!;
    user.onDelete = () {
      events.add('auth');
      original();
    };
    final auth = _auth(firebase);
    addTearDown(auth.dispose);
    await auth.deleteAccount(
      deletePrivateData: (uid, token) async {
        expect(user.lastReauthProvider, 'google.com');
        expect(uid, user.uid);
        expect(token, 'synthetic-token-${user.uid}');
        events.add('private');
      },
      deleteLocalData: () async {
        events.add('local');
      },
    );
    expect(events, ['private', 'auth', 'local']);
    expect(auth.identity, isNull);
    expect(firebase.googleSignIns, 0);
  });

  test('failed recent-login proof prevents every deletion step', () async {
    final user = _User()..reauthFailure = 'wrong-password';
    final auth = _auth(_Firebase(user));
    addTearDown(auth.dispose);
    await expectLater(
      auth.deleteAccount(
        password: 'WrongSynthetic1',
        deletePrivateData: (_, _) async =>
            fail('Private deletion happened before reauth.'),
        deleteLocalData: () async =>
            fail('Local deletion happened before reauth.'),
      ),
      throwsA(_failure('invalid_credentials')),
    );
    expect(user.deletes, 0);
  });

  test(
    'failed private cleanup retains Auth and device copy for explicit retry',
    () async {
      final user = _User();
      final auth = _auth(_Firebase(user));
      addTearDown(auth.dispose);
      await expectLater(
        auth.deleteAccount(
          password: 'Synthetic123!',
          deletePrivateData: (_, _) async => throw const AppFailure(
            'synthetic_cleanup',
            'Synthetic cleanup failure.',
          ),
          deleteLocalData: () async =>
              fail('Local data must survive failed private cleanup.'),
        ),
        throwsA(_failure('synthetic_cleanup')),
      );
      expect(user.deletes, 0);
      expect(auth.identity?.uid, user.uid);
    },
  );

  test(
    'failed SDK deletion reports partial cleanup without clearing local copy',
    () async {
      final user = _User()..deleteFailure = 'requires-recent-login';
      final auth = _auth(_Firebase(user));
      addTearDown(auth.dispose);
      var private = 0;
      await expectLater(
        auth.deleteAccount(
          password: 'Synthetic123!',
          deletePrivateData: (_, _) async {
            private++;
          },
          deleteLocalData: () async =>
              fail('Local data must survive uncertain Auth deletion.'),
        ),
        throwsA(_failure('account_delete_incomplete')),
      );
      expect(private, 1);
      expect(auth.identity?.uid, user.uid);
    },
  );

  test(
    'owner changing during private cleanup never deletes the next identity',
    () async {
      final user = _User();
      final firebase = _Firebase(user);
      final auth = _auth(firebase);
      final cleanup = Completer<void>();
      addTearDown(auth.dispose);
      await auth.start();
      final pending = auth.deleteAccount(
        password: 'Synthetic123!',
        deletePrivateData: (_, _) => cleanup.future,
        deleteLocalData: () async => fail('No other identity may be purged.'),
      );
      await Future<void>.delayed(Duration.zero);
      firebase.currentUser = _User(uid: 'synthetic-owner-b');
      firebase.changes.add(firebase.currentUser);
      cleanup.complete();
      await expectLater(pending, throwsA(_failure('account_changed')));
      expect(user.deletes, 0);
      expect(auth.identity?.uid, 'synthetic-owner-b');
    },
  );

  test('controller deletion purges only its namespace and prevents stale recreation', () async {
    final firebase = _Firebase(_User());
    final auth = _auth(firebase);
    final prefs = _Preferences();
    final sync = _DeletionSync();
    prefs.values['synthetic-unrelated-owner'] = 'keep';
    prefs.values['synthetic-guest-library'] = 'keep';
    final controller = AccountController(
      auth: auth,
      api: sync,
      guestStore: LocalStore(preferences: prefs),
      preferences: prefs,
      debounce: const Duration(days: 1),
    );
    addTearDown(controller.dispose);
    addTearDown(auth.dispose);
    await controller.start();
    await controller.refreshSync();
    final store = controller.accountStore!;
    await store.setDisplayName('Synthetic local name');
    expect(prefs.values.containsKey(store.key), isTrue);
    await controller.deleteAccount(password: 'Synthetic123!');
    expect(sync.deleted, 1);
    expect(prefs.values.containsKey(store.key), isFalse);
    expect(prefs.values['synthetic-unrelated-owner'], 'keep');
    expect(prefs.values['synthetic-guest-library'], 'keep');
    await expectLater(
      store.setDisplayName('Late old-owner write'),
      throwsA(_failure('account_deleted')),
    );
    expect(prefs.values.containsKey(store.key), isFalse);
    expect(controller.identity, isNull);
  });

  testWidgets(
    'late confirmed SDK deletion still performs local cleanup after timeout',
    (tester) async {
      final user = _User()..deleteWait = Completer<void>();
      final auth = _auth(_Firebase(user));
      addTearDown(auth.dispose);
      await auth.start();
      var local = 0;
      final pending = auth.deleteAccount(
        password: 'Synthetic123!',
        deletePrivateData: (_, _) async {},
        deleteLocalData: () async {
          local++;
        },
      );
      final timedOut = expectLater(
        pending,
        throwsA(_failure('account_unavailable')),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 16));
      await timedOut;
      expect(local, 0);
      await expectLater(auth.signInGoogle(), throwsA(_failure('account_busy')));
      user.deleteWait!.complete();
      await tester.pump();
      expect(local, 1);
      expect(auth.identity, isNull);
    },
  );

  test('Google session exposes SDK profile and provider identities', () async {
    final firebase = _Firebase();
    final auth = _auth(firebase);
    addTearDown(auth.dispose);
    await auth.signInGoogle();
    expect(auth.identity?.uid, firebase.googleResult.uid);
    expect(auth.identity?.displayName, 'Synthetic Google Name');
    expect(auth.identity?.photoUrl, firebase.googleResult.photoURL);
    expect(auth.identity?.hasGoogle, isTrue);
    expect(auth.identity?.hasPassword, isFalse);
    expect(firebase.googleSignIns, 1);
  });

  test('adding Google preserves UID and updates provider metadata', () async {
    final user = _User();
    final firebase = _Firebase(user);
    final auth = _auth(firebase);
    addTearDown(auth.dispose);
    await auth.linkGoogle();
    expect(auth.identity?.uid, user.uid);
    expect(auth.identity?.providers, {'password', 'google.com'});
    expect(user.links, 1);
    expect(firebase.googleSignIns, 0);
  });

  test(
    'Google provider profile supplies name/photo on a linked password account',
    () async {
      final user = _User()
        ..providerData.add(
          _Provider(
            'google.com',
            displayName: 'Synthetic Google Name',
            photoURL: 'https://example.invalid/synthetic-google.png',
          ),
        );
      final auth = _auth(_Firebase(user));
      addTearDown(auth.dispose);
      await auth.start();
      expect(auth.identity?.displayName, 'Synthetic Google Name');
      expect(
        auth.identity?.photoUrl,
        'https://example.invalid/synthetic-google.png',
      );
    },
  );

  test('adding password preserves Google UID and photo', () async {
    final user = _User(
      providers: ['google.com'],
      photoURL: 'https://example.invalid/synthetic-avatar.png',
    );
    final firebase = _Firebase(user);
    final auth = _auth(firebase);
    addTearDown(auth.dispose);
    await auth.linkPassword('synthetic@example.invalid', 'Synthetic123!');
    expect(auth.identity?.uid, user.uid);
    expect(auth.identity?.providers, {'google.com', 'password'});
    expect(auth.identity?.photoUrl, user.photoURL);
    expect(firebase.passwordSignIns, 0);
  });

  test(
    'credential collision never signs into or merges another account',
    () async {
      final user = _User()..linkFailure = 'credential-already-in-use';
      final firebase = _Firebase(user);
      final auth = _auth(firebase);
      addTearDown(auth.dispose);
      await expectLater(auth.linkGoogle(), throwsA(_failure('email_in_use')));
      expect(auth.identity?.uid, user.uid);
      expect(auth.identity?.providers, {'password'});
      expect(firebase.googleSignIns, 0);
    },
  );

  test(
    'a provider already linked is rejected before a new operation',
    () async {
      final user = _User(providers: ['google.com', 'password']);
      final firebase = _Firebase(user);
      final auth = _auth(firebase);
      var prompts = 0;
      final googleAuth = _auth(
        firebase,
        credential: () async {
          prompts++;
          return GoogleAuthProvider.credential(idToken: 'synthetic-id-token');
        },
      );
      addTearDown(auth.dispose);
      addTearDown(googleAuth.dispose);
      await expectLater(
        googleAuth.linkGoogle(),
        throwsA(_failure('provider_linked')),
      );
      await expectLater(
        auth.linkPassword('synthetic@example.invalid', 'Synthetic123!'),
        throwsA(_failure('provider_linked')),
      );
      expect(prompts, 0);
      expect(user.links, 0);
    },
  );

  test(
    'sign-in cannot silently replace an already signed-in account',
    () async {
      final firebase = _Firebase(_User());
      final auth = _auth(firebase);
      addTearDown(auth.dispose);
      await expectLater(
        auth.signInGoogle(),
        throwsA(_failure('account_signed_in')),
      );
      await expectLater(
        auth.signIn('another@example.invalid', 'Synthetic123!'),
        throwsA(_failure('account_signed_in')),
      );
      expect(firebase.googleSignIns, 0);
      expect(firebase.passwordSignIns, 0);
    },
  );

  test(
    'guest and anonymous sessions cannot link private account methods',
    () async {
      for (final user in [null, _User(isAnonymous: true, providers: [])]) {
        final firebase = _Firebase(user);
        final auth = _auth(firebase);
        await expectLater(
          auth.linkGoogle(),
          throwsA(_failure('account_changed')),
        );
        await expectLater(
          auth.linkPassword('synthetic@example.invalid', 'Synthetic123!'),
          throwsA(_failure('account_changed')),
        );
        expect(firebase.googleSignIns, 0);
        auth.dispose();
      }
    },
  );

  test('changing owner while Google chooser is open cancels linking', () async {
    final original = _User();
    final firebase = _Firebase(original);
    final chooser = Completer<AuthCredential>();
    final auth = _auth(firebase, credential: () => chooser.future);
    addTearDown(auth.dispose);
    await auth.start();
    final pending = auth.linkGoogle();
    await Future<void>.delayed(Duration.zero);
    firebase.currentUser = _User(uid: 'synthetic-owner-b');
    firebase.changes.add(firebase.currentUser);
    chooser.complete(
      GoogleAuthProvider.credential(idToken: 'synthetic-id-token'),
    );
    await expectLater(pending, throwsA(_failure('account_changed')));
    expect(original.links, 0);
    expect(firebase.googleSignIns, 0);
  });

  test('unexpected UID in link result is never accepted', () async {
    final original = _User()
      ..unexpectedLinkedUser = _User(uid: 'synthetic-owner-b');
    final firebase = _Firebase(original);
    final auth = _auth(firebase);
    addTearDown(auth.dispose);
    await expectLater(auth.linkGoogle(), throwsA(_failure('account_changed')));
    expect(auth.identity?.uid, original.uid);
    expect(firebase.googleSignIns, 0);
  });

  test(
    'signup upgrades anonymous UID and stores the entered name in SDK',
    () async {
      final original = _User(isAnonymous: true, providers: []);
      final firebase = _Firebase(original);
      final auth = _auth(firebase);
      addTearDown(auth.dispose);
      await auth.createWithName(
        'synthetic@example.invalid',
        'Synthetic123!',
        displayName: '  Synthetic Person  ',
      );
      expect(auth.identity?.uid, original.uid);
      expect(auth.identity?.displayName, 'Synthetic Person');
      expect(auth.identity?.providers, {'password'});
      expect(firebase.creates, 0);
    },
  );

  test(
    'profile failure after signup does not suggest repeating creation',
    () async {
      final firebase = _Firebase();
      firebase.passwordResult.failProfile = true;
      final auth = _auth(firebase);
      addTearDown(auth.dispose);
      await auth.createWithName(
        'synthetic@example.invalid',
        'Synthetic123!',
        displayName: 'Synthetic Person',
      );
      expect(auth.identity?.uid, firebase.passwordResult.uid);
      expect(firebase.creates, 1);
      await expectLater(
        auth.create('synthetic@example.invalid', 'Synthetic123!'),
        throwsA(_failure('account_signed_in')),
      );
      expect(firebase.creates, 1);
    },
  );

  test(
    'invalid signup name is rejected before creating a Firebase user',
    () async {
      final firebase = _Firebase();
      final auth = _auth(firebase);
      addTearDown(auth.dispose);
      await expectLater(
        auth.createWithName(
          'synthetic@example.invalid',
          'Synthetic123!',
          displayName: '\n',
        ),
        throwsA(_failure('invalid_name')),
      );
      expect(firebase.creates, 0);
    },
  );

  test('password reset does not disclose an unregistered email', () async {
    final firebase = _Firebase()..resetFailure = 'user-not-found';
    final auth = _auth(firebase);
    addTearDown(auth.dispose);
    await auth.resetPassword('synthetic@example.invalid');
    expect(firebase.resets, 1);
    expect(auth.identity, isNull);
  });

  test(
    'reset uses the Firebase web widget and a fixed non-sensitive return route',
    () async {
      final firebase = _Firebase();
      final auth = _auth(firebase);
      addTearDown(auth.dispose);
      await auth.resetPassword('  synthetic@example.invalid  ');
      expect(firebase.resetEmail, 'synthetic@example.invalid');
      final settings = firebase.resetSettings!;
      expect(settings.handleCodeInApp, isFalse);
      expect(settings.url, 'https://unlabel-india.vercel.app/#/account-signin');
      expect(settings.linkDomain, isNull);
      expect(settings.iOSBundleId, isNull);
      expect(settings.androidPackageName, isNull);
      final returnUrl = Uri.parse(settings.url);
      expect(returnUrl.query, isEmpty);
      expect(returnUrl.fragment, '/account-signin');
      expect(settings.url, isNot(contains('synthetic@example.invalid')));
      expect(settings.url, isNot(contains('oobCode')));
      expect(auth.identity, isNull);
    },
  );

  test(
    'reset validation and rate-limit errors do not claim an email was sent',
    () async {
      for (final entry in {
        'invalid-email': 'invalid_email',
        'too-many-requests': 'rate_limited',
      }.entries) {
        final firebase = _Firebase()..resetFailure = entry.key;
        final auth = _auth(firebase);
        await expectLater(
          auth.resetPassword('synthetic@example.invalid'),
          throwsA(_failure(entry.value)),
        );
        expect(firebase.resets, 1);
        expect(auth.identity, isNull);
        auth.dispose();
      }
    },
  );

  test(
    'reset email keeps signed-in owner, library and unresolved sync choice',
    () async {
      final firebase = _Firebase(_User());
      final auth = _auth(firebase);
      final prefs = _Preferences();
      final sync = _Sync();
      final controller = AccountController(
        auth: auth,
        api: sync,
        guestStore: LocalStore(preferences: prefs),
        preferences: prefs,
        debounce: const Duration(days: 1),
      );
      addTearDown(controller.dispose);
      addTearDown(auth.dispose);
      await controller.start();
      await controller.refreshSync();
      final store = controller.accountStore;
      final state = controller.state;
      final cancelled = sync.cancellations;
      await controller.resetPassword('synthetic@example.invalid');
      expect(controller.identity?.uid, firebase.currentUser?.uid);
      expect(identical(controller.accountStore, store), isTrue);
      expect(controller.state, state);
      expect(sync.cancellations, cancelled);
      expect(sync.writes, 0);
    },
  );

  testWidgets(
    'timed-out reset request stays single-flight without duplicate email',
    (tester) async {
      final firebase = _Firebase()..resetWait = Completer<void>();
      final auth = _auth(firebase);
      addTearDown(auth.dispose);
      await auth.start();
      final pending = auth.resetPassword('synthetic@example.invalid');
      final timeout = expectLater(
        pending,
        throwsA(_failure('account_unavailable')),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 16));
      await timeout;
      await expectLater(
        auth.resetPassword('synthetic@example.invalid'),
        throwsA(_failure('account_busy')),
      );
      expect(firebase.resets, 1);
      firebase.resetWait!.complete();
      await tester.pump();
      expect(firebase.resets, 1);
      expect(auth.identity, isNull);
    },
  );

  testWidgets(
    'timed-out provider chooser remains single-flight until it finishes',
    (tester) async {
      final firebase = _Firebase();
      final chooser = Completer<AuthCredential>();
      final auth = _auth(firebase, credential: () => chooser.future);
      addTearDown(auth.dispose);
      await auth.start();
      final pending = auth.signInGoogle();
      final timeout = expectLater(
        pending,
        throwsA(_failure('account_unavailable')),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 16));
      await timeout;
      await expectLater(auth.signInGoogle(), throwsA(_failure('account_busy')));
      expect(firebase.googleSignIns, 0);
      chooser.complete(
        GoogleAuthProvider.credential(idToken: 'synthetic-id-token'),
      );
      await tester.pump();
      expect(firebase.googleSignIns, 1);
      expect(auth.identity?.uid, firebase.googleResult.uid);
    },
  );

  test(
    'same-UID linking preserves local store and unresolved sync choice',
    () async {
      final firebase = _Firebase(_User());
      final auth = _auth(firebase);
      final prefs = _Preferences();
      final sync = _Sync();
      final controller = AccountController(
        auth: auth,
        api: sync,
        guestStore: LocalStore(preferences: prefs),
        preferences: prefs,
        debounce: const Duration(days: 1),
      );
      addTearDown(controller.dispose);
      addTearDown(auth.dispose);
      await controller.start();
      await controller.refreshSync();
      expect(controller.state, AccountSyncState.needsChoice);
      final store = controller.accountStore;
      final before = await store!.snapshot();
      final cancelled = sync.cancellations;
      await controller.linkGoogle();
      expect(identical(controller.accountStore, store), isTrue);
      expect(controller.state, AccountSyncState.needsChoice);
      expect(controller.identity?.hasGoogle, isTrue);
      expect(sync.cancellations, cancelled);
      expect(sync.writes, 0);
      expect((await store.snapshot()).data.sameContent(before.data), isTrue);
      await controller.useCloud();
      expect(controller.localData?.displayName, 'Existing cloud name');
    },
  );
}
