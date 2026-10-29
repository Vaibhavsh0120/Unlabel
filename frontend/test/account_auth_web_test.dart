import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/core/accounts/account_auth.dart';
import 'package:unlabel/core/models/app_failure.dart';

class _Credential implements UserCredential {
  _Credential(this.user);
  @override
  final User? user;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Provider implements UserInfo {
  _Provider(this.providerId);
  @override
  final String providerId;
  @override
  String? get displayName => null;
  @override
  String? get photoURL => null;
  @override
  String? get email => 'synthetic@example.invalid';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements User {
  _User({List<String> providers = const ['password']})
    : providerData = providers.map(_Provider.new).toList();
  int redirects = 0, unlinks = 0;
  @override
  String get uid => 'synthetic-owner';
  @override
  bool get isAnonymous => false;
  @override
  String get email => 'synthetic@example.invalid';
  @override
  String? get displayName => null;
  @override
  String? get photoURL => null;
  @override
  final List<UserInfo> providerData;
  @override
  Future<UserCredential> linkWithPopup(AuthProvider provider) async =>
      throw FirebaseAuthException(code: 'popup-blocked');
  @override
  Future<void> linkWithRedirect(AuthProvider provider) async {
    redirects++;
  }

  @override
  Future<void> reload() async {}

  @override
  Future<UserCredential> reauthenticateWithPopup(AuthProvider provider) async =>
      throw FirebaseAuthException(code: 'popup-blocked');

  @override
  Future<User> unlink(String providerId) async {
    unlinks++;
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Firebase implements FirebaseAuth {
  _Firebase([this.currentUser]);
  @override
  User? currentUser;
  String? popupError = 'popup-blocked';
  String? redirectError;
  Completer<void>? redirectWait;
  int subscriptions = 0;
  int redirects = 0, redirectResults = 0;
  @override
  Stream<User?> authStateChanges() {
    subscriptions++;
    return Stream.value(currentUser);
  }

  @override
  Future<UserCredential> getRedirectResult() async {
    redirectResults++;
    if (redirectWait != null) await redirectWait!.future;
    if (redirectError != null) {
      throw FirebaseAuthException(code: redirectError!);
    }
    return _Credential(currentUser);
  }

  @override
  Future<UserCredential> signInWithPopup(AuthProvider provider) async {
    if (popupError != null) throw FirebaseAuthException(code: popupError!);
    return _Credential(currentUser = _User());
  }

  @override
  Future<void> signInWithRedirect(AuthProvider provider) async {
    redirects++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

FirebaseAccountAuth _auth(_Firebase firebase) => FirebaseAccountAuth(
  options: const FirebaseOptions(
    apiKey: 'synthetic-key',
    appId: 'synthetic-app',
    messagingSenderId: 'synthetic-sender',
    projectId: 'synthetic-project',
  ),
  firebaseAuth: firebase,
  isWeb: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('blocked Google popup continues in the current browser tab', () async {
    final firebase = _Firebase();
    final auth = _auth(firebase);
    addTearDown(auth.dispose);
    await auth.start();
    await auth.signInGoogle();
    expect(firebase.redirects, 1);
    expect(auth.identity, isNull);
  });

  test('cancelled Google popup does not navigate away', () async {
    final firebase = _Firebase()..popupError = 'popup-closed-by-user';
    final auth = _auth(firebase);
    addTearDown(auth.dispose);
    await auth.start();
    await expectLater(
      auth.signInGoogle(),
      throwsA(
        isA<AppFailure>().having((e) => e.kind, 'kind', 'account_cancelled'),
      ),
    );
    expect(firebase.redirects, 0);
    expect(auth.identity, isNull);
  });

  test('Google credential collision never retries through redirect', () async {
    final firebase = _Firebase()..popupError = 'credential-already-in-use';
    final auth = _auth(firebase);
    addTearDown(auth.dispose);
    await auth.start();
    await expectLater(
      auth.signInGoogle(),
      throwsA(isA<AppFailure>().having((e) => e.kind, 'kind', 'email_in_use')),
    );
    expect(firebase.redirects, 0);
    expect(auth.identity, isNull);
  });

  test('successful Google popup does not redirect', () async {
    final firebase = _Firebase()..popupError = null;
    final auth = _auth(firebase);
    addTearDown(auth.dispose);
    await auth.start();
    await auth.signInGoogle();
    expect(firebase.redirects, 0);
    expect(auth.identity?.uid, 'synthetic-owner');
  });

  test('failed Google reauthentication cannot replay an unlink', () async {
    final user = _User(providers: ['password', 'google.com']);
    final firebase = _Firebase(user);
    final auth = _auth(firebase);
    addTearDown(auth.dispose);
    await auth.start();
    await expectLater(
      auth.unlinkPassword(),
      throwsA(isA<AppFailure>().having((e) => e.kind, 'kind', 'popup_blocked')),
    );
    expect(user.unlinks, 0);
    expect(user.redirects, 0);
    expect(firebase.redirects, 0);
    expect(auth.identity?.uid, 'synthetic-owner');
  });

  test(
    'blocked Google linking keeps the owner and uses a link redirect',
    () async {
      final user = _User();
      final firebase = _Firebase(user);
      final auth = _auth(firebase);
      addTearDown(auth.dispose);
      await auth.start();
      await auth.linkGoogle();
      expect(user.redirects, 1);
      expect(firebase.redirects, 0);
      expect(auth.identity?.uid, 'synthetic-owner');
    },
  );

  test(
    'startup completes the Google redirect before publishing the session',
    () async {
      final firebase = _Firebase(_User());
      final auth = _auth(firebase);
      addTearDown(auth.dispose);
      await auth.start();
      expect(firebase.redirectResults, 1);
      expect(auth.identity?.uid, 'synthetic-owner');
    },
  );

  test('redirect credential errors keep their safe account message', () async {
    final firebase = _Firebase()..redirectError = 'credential-already-in-use';
    final auth = _auth(firebase);
    addTearDown(auth.dispose);
    await expectLater(
      auth.start(),
      throwsA(isA<AppFailure>().having((e) => e.kind, 'kind', 'email_in_use')),
    );
    expect(firebase.redirects, 0);
    expect(auth.identity, isNull);
  });

  test(
    'failed link redirect restores its existing owner before the error',
    () async {
      final firebase = _Firebase(_User())
        ..redirectError = 'credential-already-in-use';
      final auth = _auth(firebase);
      addTearDown(auth.dispose);
      await expectLater(
        auth.start(),
        throwsA(
          isA<AppFailure>().having((e) => e.kind, 'kind', 'email_in_use'),
        ),
      );
      expect(auth.identity?.uid, 'synthetic-owner');
      await auth.start();
      expect(firebase.redirectResults, 1);
      expect(auth.identity?.uid, 'synthetic-owner');
    },
  );

  test(
    'disposing during redirect restoration never subscribes afterward',
    () async {
      final firebase = _Firebase()..redirectWait = Completer<void>();
      final auth = _auth(firebase);
      final pending = auth.start();
      auth.dispose();
      firebase.redirectWait!.complete();
      await pending;
      expect(firebase.subscriptions, 0);
    },
  );
}
