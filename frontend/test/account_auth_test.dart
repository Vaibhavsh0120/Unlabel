import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/core/accounts/account_auth.dart';
import 'package:unlabel/core/accounts/account_controller.dart';
import 'package:unlabel/core/accounts/account_data.dart';
import 'package:unlabel/core/accounts/account_sync_api.dart';
import 'package:unlabel/core/models/app_failure.dart';
import 'package:unlabel/core/storage/local_store.dart';

class _Provider implements UserInfo {
  _Provider(this.providerId, {this.displayName, this.photoURL});
  @override
  final String providerId;
  @override
  final String? displayName;
  @override
  final String? photoURL;
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

  @override
  Future<UserCredential> linkWithCredential(AuthCredential credential) async {
    links++;
    if (linkFailure != null) throw FirebaseAuthException(code: linkFailure!);
    providerData.add(_Provider(credential.providerId));
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Firebase implements FirebaseAuth {
  _Firebase([this.currentUser]);
  @override
  User? currentUser;
  final changes = StreamController<User?>.broadcast();
  int googleSignIns = 0;
  int passwordSignIns = 0;
  int creates = 0;
  int resets = 0;
  int verifies = 0;
  int confirms = 0;
  _User googleResult = _User(
    displayName: 'Synthetic Google Name',
    photoURL: 'https://example.invalid/synthetic-avatar.png',
    providers: ['google.com'],
  );
  _User passwordResult = _User();
  String? resetFailure;
  String? verifyFailure;
  String? confirmFailure;

  @override
  Stream<User?> authStateChanges() async* {
    yield currentUser;
    yield* changes.stream;
  }

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    googleSignIns++;
    currentUser = googleResult;
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
    changes.add(currentUser);
    return _Credential(currentUser!);
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    resets++;
    if (resetFailure != null) throw FirebaseAuthException(code: resetFailure!);
  }

  @override
  Future<String> verifyPasswordResetCode(String code) async {
    verifies++;
    if (verifyFailure != null) {
      throw FirebaseAuthException(code: verifyFailure!);
    }
    return 'synthetic@example.invalid';
  }

  @override
  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    confirms++;
    if (confirmFailure != null) {
      throw FirebaseAuthException(code: confirmFailure!);
    }
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    'reset code is verified and applied without changing signed-in owner',
    () async {
      final owner = _User();
      final firebase = _Firebase(owner);
      final auth = _auth(firebase);
      addTearDown(auth.dispose);
      expect(
        await auth.verifyPasswordResetCode('synthetic-code'),
        'synthetic@example.invalid',
      );
      await auth.confirmPasswordReset('synthetic-code', 'Synthetic123!');
      expect(firebase.verifies, 1);
      expect(firebase.confirms, 1);
      expect(auth.identity?.uid, owner.uid);
    },
  );

  test('expired reset links have actionable neutral errors', () async {
    final firebase = _Firebase()..verifyFailure = 'expired-action-code';
    final auth = _auth(firebase);
    addTearDown(auth.dispose);
    await expectLater(
      auth.verifyPasswordResetCode('synthetic-expired-code'),
      throwsA(_failure('invalid_reset_code')),
    );
    await expectLater(
      auth.verifyPasswordResetCode(''),
      throwsA(_failure('invalid_reset_code')),
    );
    expect(firebase.verifies, 1);
  });

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
