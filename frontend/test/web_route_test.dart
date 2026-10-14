import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/app/unlabel_app.dart';
import 'package:unlabel/app/web_route.dart';
import 'package:unlabel/core/accounts/account_auth.dart';
import 'package:unlabel/core/accounts/account_controller.dart';
import 'package:unlabel/core/accounts/account_data.dart';
import 'package:unlabel/core/accounts/account_sync_api.dart';
import 'package:unlabel/core/network/unlabel_repository.dart';
import 'package:unlabel/core/storage/local_store.dart';
import 'package:unlabel/features/account/presentation/auth_page.dart';
import 'package:unlabel/features/account/presentation/profile_page.dart';
import 'package:unlabel/features/scanner/presentation/welcome_page.dart';

class _Preferences implements PreferencesAdapter {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> remove(String key) async => values.remove(key);
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _NoSync implements AccountSyncTransport {
  @override
  Future<bool> available() async => false;
  @override
  Future<AccountSnapshot> fetch(String token) async =>
      throw StateError('A sign-in return must not fetch private reports.');
  @override
  Future<AccountSnapshot> put(String token, AccountMutation mutation) async =>
      throw StateError('A sign-in return must not upload private reports.');
  @override
  void cancelAll() {}
  @override
  void close() {}
}

class _EntryAuth extends UnavailableAccountAuth {
  _EntryAuth({this.restoredIdentity, this.restoreWait});
  final AccountIdentity? restoredIdentity;
  final Completer<void>? restoreWait;
  AccountIdentity? _identity;
  int signOuts = 0;
  @override
  AccountIdentity? get identity => _identity;
  @override
  Future<void> start() async {
    if (restoreWait != null) await restoreWait!.future;
    _identity = restoredIdentity;
    notifyListeners();
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    _identity = null;
    notifyListeners();
  }
}

class _EntryController extends AccountController {
  _EntryController(LocalStore store, {_EntryAuth? session})
    : super(
        auth: session ?? _EntryAuth(),
        api: _NoSync(),
        guestStore: store,
        preferences: store.preferences,
      );

  int signIns = 0;
  @override
  Future<void> signIn(String email, String password) async => signIns++;
}

class _DelayedWelcomeStore extends LocalStore {
  _DelayedWelcomeStore(_Preferences preferences)
    : super(preferences: preferences);
  final initialWelcome = Completer<bool>();
  @override
  Future<bool> welcomeCompleted() => initialWelcome.future;
}

Widget _app(LocalStore store, _EntryController account, Uri uri) {
  final repository = UnlabelRepository(baseUrl: 'https://example.invalid');
  addTearDown(() {
    account.dispose();
    account.auth.dispose();
    repository.close();
  });
  return UnlabelApp(
    repository: repository,
    store: store,
    accountController: account,
    initialUri: uri,
  );
}

void main() {
  testWidgets(
    'reset return restores an existing owner to Profile without signing out',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final restored = Completer<void>();
      final session = _EntryAuth(
        restoredIdentity: const AccountIdentity(
          uid: 'synthetic-existing-owner',
          email: 'synthetic@example.invalid',
          providers: {'password'},
        ),
        restoreWait: restored,
      );
      final store = LocalStore(preferences: _Preferences());
      final account = _EntryController(store, session: session);
      await tester.pumpWidget(
        _app(
          store,
          account,
          Uri.parse('https://unlabel-india.vercel.app/#/account-signin'),
        ),
      );
      await tester.pump();
      expect(find.byType(AuthPage), findsNothing);
      expect(find.byType(ProfilePage), findsNothing);
      restored.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AuthPage), findsNothing);
      expect(find.byType(ProfilePage), findsOneWidget);
      expect(find.byType(WelcomePage), findsNothing);
      expect(account.identity?.uid, 'synthetic-existing-owner');
      expect(session.signOuts, 0);
      expect(account.signIns, 0);
      expect(find.text('synthetic@example.invalid'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('account-return-home')));
      await tester.pumpAndSettle();
      expect(find.byType(ProfilePage), findsNothing);
      expect(find.text('Recent scans'), findsOneWidget);
      expect(account.identity?.uid, 'synthetic-existing-owner');
      expect(session.signOuts, 0);
      expect(tester.takeException(), isNull);
    },
  );

  test('only the exact queryless sign-in fragment opens the return flow', () {
    for (final value in [
      'https://unlabel-india.vercel.app/#/account-signin',
      'https://unlabel-india.vercel.app#/account-signin',
      'http://127.0.0.1:8770/#/account-signin',
      'http://localhost:8770/#/account-signin',
      'http://[::1]:8770/#/account-signin',
    ]) {
      expect(
        isAccountSignInReturnUri(Uri.parse(value), rawUrl: value),
        isTrue,
        reason: value,
      );
    }
  });

  test(
    'nested, encoded, queried and credential-bearing returns are rejected',
    () {
      for (final value in [
        'https://unlabel-india.vercel.app/',
        'https://unlabel-india.vercel.app/account-signin',
        'https://unlabel-india.vercel.app/another/#/account-signin',
        'https://unlabel-india.vercel.app/#/account-signin/',
        'https://unlabel-india.vercel.app/#/account-signin?next=/',
        'https://unlabel-india.vercel.app/?#/account-signin',
        'https://unlabel-india.vercel.app/?mode=resetPassword#/account-signin',
        'https://unlabel-india.vercel.app/#/%61ccount-signin',
        'https://user@unlabel-india.vercel.app/#/account-signin',
        'http://unlabel-india.vercel.app/#/account-signin',
        'file:///#/account-signin',
        'javascript:account-signin',
      ]) {
        expect(
          isAccountSignInReturnUri(Uri.parse(value), rawUrl: value),
          isFalse,
          reason: value,
        );
      }
    },
  );

  test(
    'no password-action code or nested Continue URL enters the app flow',
    () {
      for (final value in [
        'https://unlabel-india.vercel.app/?mode=resetPassword&oobCode=synthetic-code',
        'https://unlabel-india.vercel.app/#/account-reset?mode=resetPassword&oobCode=synthetic-code',
        'https://unlabel-india.vercel.app/#/account-signin?oobCode=synthetic-code',
        'https://unlabel-india.vercel.app/?continueUrl=https%3A%2F%2Funlabel-india.vercel.app%2F%23%2Faccount-signin',
        'https://unlabel-india.vercel.app/?mode=verifyEmail&oobCode=synthetic-code',
      ]) {
        expect(
          isAccountSignInReturnUri(Uri.parse(value), rawUrl: value),
          isFalse,
          reason: value,
        );
      }
    },
  );

  testWidgets('root sign-in completion replaces the form with Home', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final store = LocalStore(preferences: _Preferences());
    final account = _EntryController(store);
    await tester.pumpWidget(
      _app(
        store,
        account,
        Uri.parse('https://unlabel-india.vercel.app/#/account-signin'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AuthPage), findsOneWidget);
    expect(find.byType(WelcomePage), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      'synthetic@example.invalid',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password')),
      'Existing123',
    );
    await tester.tap(find.byKey(const ValueKey('account-submit')));
    await tester.pumpAndSettle();
    expect(account.signIns, 1);
    expect(find.byType(AuthPage), findsNothing);
    expect(find.byType(WelcomePage), findsNothing);
    expect(find.text('Recent scans'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'guest exit survives a delayed Welcome read without returning to auth',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = _DelayedWelcomeStore(_Preferences());
      final account = _EntryController(store);
      await tester.pumpWidget(
        _app(
          store,
          account,
          Uri.parse('https://unlabel-india.vercel.app/#/account-signin'),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('auth-guest')));
      await tester.pump();
      store.initialWelcome.complete(false);
      await tester.pumpAndSettle();
      expect(account.signIns, 0);
      expect(find.byType(AuthPage), findsNothing);
      expect(find.byType(WelcomePage), findsNothing);
      expect(find.text('Recent scans'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
