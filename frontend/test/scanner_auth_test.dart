import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/core/network/scanner_auth.dart';

class _Provider implements UserInfo {
  _Provider(this.providerId);
  @override
  final String providerId;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements User {
  _User({
    this.uid = 'synthetic-owner',
    this.isAnonymous = false,
    List<String> providers = const ['google.com'],
  }) : providerData = providers.map(_Provider.new).toList();
  @override
  final String uid;
  @override
  final bool isAnonymous;
  @override
  final List<UserInfo> providerData;
  String token = 'synthetic-token';
  bool fail = false;
  int reads = 0;
  Completer<String?>? pending;
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    reads++;
    if (fail) throw FirebaseAuthException(code: 'network-request-failed');
    return pending == null ? token : await pending!.future;
  }

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

class _Firebase implements FirebaseAuth {
  _Firebase([this.currentUser]);
  @override
  User? currentUser;
  int anonymousSignIns = 0;
  @override
  Future<UserCredential> signInAnonymously() async {
    anonymousSignIns++;
    currentUser = _User(
      uid: 'synthetic-guest',
      isAnonymous: true,
      providers: const [],
    );
    return _Credential(currentUser!);
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

FirebaseScannerAuth _scanner(_Firebase firebase) => FirebaseScannerAuth(
  options: _options,
  resolveAuth: (options) async {
    expect(options, same(_options));
    return firebase;
  },
);

void main() {
  test(
    'Google-only scanner retains the SDK owner and receives refreshed tokens',
    () async {
      final user = _User();
      final firebase = _Firebase(user);
      final scanner = _scanner(firebase);
      expect(await scanner.token(), 'synthetic-token');
      user.token = 'synthetic-refreshed-token';
      expect(await scanner.token(), 'synthetic-refreshed-token');
      expect(firebase.currentUser, same(user));
      expect(firebase.currentUser!.uid, 'synthetic-owner');
      expect(firebase.anonymousSignIns, 0);
      expect(user.reads, 2);
    },
  );

  for (final providers in [
    <String>['password'],
    <String>['password', 'google.com'],
  ]) {
    test(
      'existing $providers session is retained for scanner requests',
      () async {
        final user = _User(providers: providers);
        final firebase = _Firebase(user);
        expect(await _scanner(firebase).token(), 'synthetic-token');
        expect(firebase.currentUser, same(user));
        expect(firebase.anonymousSignIns, 0);
        expect(user.reads, 1);
      },
    );
  }

  test(
    'guest authentication is created once and its SDK session is reused',
    () async {
      final firebase = _Firebase();
      final scanner = _scanner(firebase);
      expect(await scanner.token(), 'synthetic-token');
      final guest = firebase.currentUser;
      expect(guest!.isAnonymous, isTrue);
      expect(await scanner.token(), 'synthetic-token');
      expect(firebase.currentUser, same(guest));
      expect(firebase.anonymousSignIns, 1);
    },
  );

  test(
    'unsupported providers receive no token and are never replaced by a guest',
    () async {
      for (final providers in [
        <String>[],
        <String>['apple.com'],
        <String>['oidc.synthetic'],
      ]) {
        final user = _User(providers: providers);
        final firebase = _Firebase(user);
        expect(await _scanner(firebase).token(), isNull);
        expect(firebase.currentUser, same(user));
        expect(firebase.anonymousSignIns, 0);
        expect(user.reads, 0);
      }
    },
  );

  test(
    'SDK token failure leaves the signed-in Google session untouched',
    () async {
      final user = _User()..fail = true;
      final firebase = _Firebase(user);
      expect(await _scanner(firebase).token(), isNull);
      expect(firebase.currentUser, same(user));
      expect(firebase.anonymousSignIns, 0);
      expect(user.reads, 1);
    },
  );

  test(
    'concurrent Google scanner requests share one SDK token operation',
    () async {
      final user = _User()..pending = Completer<String?>();
      final firebase = _Firebase(user);
      var resolutions = 0;
      final scanner = FirebaseScannerAuth(
        options: _options,
        resolveAuth: (_) async {
          resolutions++;
          return firebase;
        },
      );
      final first = scanner.token();
      final second = scanner.token();
      await Future<void>.delayed(Duration.zero);
      expect(resolutions, 1);
      expect(user.reads, 1);
      user.pending!.complete('synthetic-coalesced-token');
      expect(await first, 'synthetic-coalesced-token');
      expect(await second, 'synthetic-coalesced-token');
      expect(firebase.currentUser, same(user));
      expect(firebase.anonymousSignIns, 0);
    },
  );
}
