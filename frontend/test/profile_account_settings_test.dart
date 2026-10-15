import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/app/unlabel_theme.dart';
import 'package:unlabel/core/accounts/account_auth.dart';
import 'package:unlabel/core/accounts/account_controller.dart';
import 'package:unlabel/core/accounts/account_data.dart';
import 'package:unlabel/core/accounts/account_sync_api.dart';
import 'package:unlabel/core/accounts/profile_media.dart';
import 'package:unlabel/core/models/app_failure.dart';
import 'package:unlabel/core/storage/local_store.dart';
import 'package:unlabel/features/account/presentation/profile_avatar.dart';
import 'package:unlabel/features/account/presentation/profile_page.dart';

class _Preferences implements PreferencesAdapter {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
}

class _Auth extends UnavailableAccountAuth {
  _Auth(Set<String> providers)
    : user = AccountIdentity(
        uid: 'synthetic-owner',
        email: 'synthetic@example.invalid',
        displayName: 'Synthetic Man',
        providers: providers,
      );
  AccountIdentity user;
  int googleLinks = 0, passwordLinks = 0;
  String? linkedEmail, linkedPassword;
  Completer<void>? pending;
  AppFailure? failure;
  @override
  AccountIdentity get identity => user;
  @override
  Future<String> token(String expectedUid) async => 'synthetic-token';

  Future<void> _link(String provider) async {
    await pending?.future;
    if (failure != null) throw failure!;
    user = AccountIdentity(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      providers: {...user.providers, provider},
    );
    notifyListeners();
  }

  @override
  Future<void> linkGoogle() async {
    googleLinks++;
    await _link('google.com');
  }

  @override
  Future<void> linkPassword(String email, String password) async {
    passwordLinks++;
    linkedEmail = email;
    linkedPassword = password;
    await _link('password');
  }
}

class _Sync implements AccountSyncTransport {
  int fetches = 0;
  @override
  Future<bool> available() async => true;
  @override
  Future<AccountSnapshot> fetch(String token) async {
    fetches++;
    return AccountSnapshot(revision: 0, data: AccountData());
  }

  @override
  Future<AccountSnapshot> put(String token, AccountMutation mutation) async =>
      throw StateError('Settings must not upload or merge a report library.');
  @override
  void cancelAll() {}
  @override
  void close() {}
}

class _MediaRepository implements ProfileMediaRepository {
  _MediaRepository(this.initial);
  final ProfileMedia initial;
  int watches = 0;
  final writes = <(String, ProfileMedia)>[];
  @override
  Stream<ProfileMedia> watch(String uid) {
    watches++;
    return Stream.value(initial);
  }

  @override
  Future<void> write(String uid, ProfileMedia value) async {
    writes.add((uid, value));
  }
}

class _Fixture {
  _Fixture(this.auth, this.account, this.media, this.repository, this.sync);
  final _Auth auth;
  final AccountController account;
  final ProfileMediaController media;
  final _MediaRepository repository;
  final _Sync sync;
  bool _disposed = false;

  static Future<_Fixture> create({
    Set<String> providers = const {'password'},
    ProfileMedia? initial,
  }) async {
    final preferences = _Preferences();
    final auth = _Auth(providers);
    final sync = _Sync();
    final account = AccountController(
      auth: auth,
      api: sync,
      preferences: preferences,
      guestStore: LocalStore(preferences: preferences),
      debounce: const Duration(days: 1),
    );
    final repository = _MediaRepository(initial ?? ProfileMedia());
    final media = ProfileMediaController(
      auth: auth,
      preferences: preferences,
      repository: repository,
    );
    await account.start();
    await account.refreshSync();
    await media.start();
    return _Fixture(auth, account, media, repository, sync);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    media.dispose();
    account.dispose();
    auth.dispose();
  }
}

Future<void> _open(
  WidgetTester tester,
  _Fixture fixture, {
  Size size = const Size(390, 844),
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: UnlabelTheme.forBrightness(brightness),
      builder: (context, child) => ProfileMediaScope(
        controller: fixture.media,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: child!,
        ),
      ),
      home: ProfilePage(controller: fixture.account, onContinue: () {}),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<Uint8List> _thumbnail() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 192, 192),
    Paint()..color = Colors.green,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(192, 192);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  for (final providers in [
    {'password'},
    {'google.com'},
  ]) {
    testWidgets('the only remaining provider cannot be disabled: $providers', (
      tester,
    ) async {
      final fixture = await _Fixture.create(providers: providers);
      addTearDown(fixture.dispose);
      await _open(tester, fixture);
      await _tap(tester, find.text('Sign-in methods'));
      final passwordSwitch = tester.widget<Switch>(
        find.byKey(const ValueKey('sign-in-password-toggle')),
      );
      expect(passwordSwitch.value, providers.contains('password'));
      expect(passwordSwitch.onChanged == null, providers.contains('password'));
      final google = tester.widget<TextButton>(
        find.widgetWithText(
          TextButton,
          providers.contains('google.com') ? 'Disconnect' : 'Connect Google',
        ),
      );
      expect(google.onPressed == null, providers.contains('google.com'));
      expect(fixture.account.identity!.providers, providers);
      expect(tester.takeException(), isNull);
    });
  }
  for (final size in [
    const Size(320, 700),
    const Size(390, 844),
    const Size(1440, 900),
  ]) {
    testWidgets('linked methods fit reference viewport $size', (tester) async {
      final fixture = await _Fixture.create(
        providers: {'password', 'google.com'},
      );
      addTearDown(fixture.dispose);
      await _open(tester, fixture, size: size);
      await _tap(tester, find.text('Sign-in methods'));
      expect(find.text('Connected'), findsOneWidget);
      expect(
        tester
            .widget<Switch>(
              find.byKey(const ValueKey('sign-in-password-toggle')),
            )
            .value,
        isTrue,
      );
      expect(
        tester
            .widget<Switch>(
              find.byKey(const ValueKey('sign-in-password-toggle')),
            )
            .onChanged,
        isNotNull,
      );
      expect(
        tester.getTopLeft(find.text('Email & password')).dy,
        lessThan(tester.getTopLeft(find.text('Google account')).dy),
      );
      for (final label in [
        'Disconnect',
        'Both methods can be active at once',
        'Keep your account secure',
        'Delete account',
      ]) {
        await tester.ensureVisible(find.text(label));
        final rect = tester.getRect(find.text(label));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(size.width));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
      }
      await _tap(tester, find.byTooltip('Email and password options'));
      expect(find.text('Change email'), findsOneWidget);
      expect(find.text('Change password'), findsOneWidget);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      await _tap(tester, find.byTooltip('Google account options'));
      expect(find.text('Switch account'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'gender stays optional and changing it preserves a custom photo',
    (tester) async {
      final bytes = (await tester.runAsync(_thumbnail))!;
      final fixture = await _Fixture.create(
        initial: ProfileMedia(
          source: ProfileAvatarSource.custom,
          avatarPng: bytes,
        ),
      );
      addTearDown(fixture.dispose);
      await _open(tester, fixture);
      // A name or provider never selects a gender on the person's behalf.
      expect(fixture.auth.identity.displayName, 'Synthetic Man');
      expect(fixture.media.value.gender, ProfileGender.unspecified);
      await _tap(tester, find.text('Gender'));
      expect(
        find.text('Optional. This selects your default avatar.'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Prefer not to say'),
        ),
        findsOneWidget,
      );
      await _tap(tester, find.text('Female'));
      expect(fixture.media.value.gender, ProfileGender.female);
      expect(fixture.media.value.source, ProfileAvatarSource.custom);
      expect(fixture.media.value.avatarPng, orderedEquals(bytes));
      expect(fixture.repository.writes.single.$1, 'synthetic-owner');
      expect(
        fixture.repository.writes.single.$2.avatarPng,
        orderedEquals(bytes),
      );
      expect(tester.takeException(), isNull);
      await _tap(tester, find.text('Gender'));
      await _tap(tester, find.text('Prefer not to say'));
      expect(fixture.media.value.gender, ProfileGender.unspecified);
      expect(fixture.media.value.source, ProfileAvatarSource.custom);
    },
  );

  testWidgets(
    'password account links Google once without changing its UID or library',
    (tester) async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      await fixture.account.updateDisplayName('Private library name');
      await _open(tester, fixture);
      final originalStore = fixture.account.accountStore;
      final fetches = fixture.sync.fetches;
      await _tap(tester, find.text('Sign-in methods'));
      expect(
        tester
            .widget<Switch>(
              find.byKey(const ValueKey('sign-in-password-toggle')),
            )
            .value,
        isTrue,
      );
      expect(find.text('Add email and password'), findsNothing);
      fixture.auth.pending = Completer<void>();
      final connect = find.text('Connect Google');
      await tester.ensureVisible(connect);
      await tester.tap(connect);
      await tester.pump();
      expect(fixture.auth.googleLinks, 1);
      expect(fixture.account.authBusy, isTrue);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Back'))
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(
        find.byKey(const ValueKey('profile-sign-in-methods')),
        findsOneWidget,
      );
      fixture.auth.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Connected'), findsOneWidget);
      expect(
        tester
            .widget<Switch>(
              find.byKey(const ValueKey('sign-in-password-toggle')),
            )
            .value,
        isTrue,
      );
      expect(find.text('Connect Google'), findsNothing);
      expect(fixture.account.identity!.uid, 'synthetic-owner');
      expect(fixture.account.identity!.providers, {'password', 'google.com'});
      expect(identical(fixture.account.accountStore, originalStore), isTrue);
      expect(fixture.account.localData!.displayName, 'Private library name');
      expect(fixture.repository.watches, 1);
      expect(fixture.sync.fetches, fetches);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      fixture.dispose();
    },
  );

  testWidgets(
    'Google account adds a strong matching password to the same UID',
    (tester) async {
      final fixture = await _Fixture.create(providers: {'google.com'});
      addTearDown(fixture.dispose);
      await _open(tester, fixture);
      final originalStore = fixture.account.accountStore;
      await _tap(tester, find.text('Sign-in methods'));
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Connect Google'), findsNothing);
      await _tap(tester, find.text('Add email and password'));
      expect(find.text('Add a password'), findsOneWidget);
      final password = find.widgetWithText(TextFormField, 'New password');
      final confirm = find.widgetWithText(TextFormField, 'Confirm password');
      await tester.enterText(password, 'password123');
      await tester.enterText(confirm, 'password123');
      await _tap(tester, find.text('Add password'));
      expect(find.text('Choose a less common password.'), findsOneWidget);
      expect(fixture.auth.passwordLinks, 0);
      await tester.enterText(password, 'UniqueField42');
      await tester.enterText(confirm, 'DifferentField42');
      await _tap(tester, find.text('Add password'));
      expect(find.text('Passwords must match.'), findsOneWidget);
      expect(fixture.auth.passwordLinks, 0);
      await tester.enterText(confirm, 'UniqueField42');
      fixture.auth.pending = Completer<void>();
      final add = find.text('Add password');
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pump();
      expect(fixture.auth.passwordLinks, 1);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton &&
                    widget.tooltip == 'Close Add a password',
              ),
            )
            .onPressed,
        isNull,
      );
      fixture.auth.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Add a password'), findsNothing);
      expect(find.text('Connected'), findsOneWidget);
      expect(
        tester
            .widget<Switch>(
              find.byKey(const ValueKey('sign-in-password-toggle')),
            )
            .value,
        isTrue,
      );
      expect(fixture.auth.linkedEmail, 'synthetic@example.invalid');
      expect(fixture.auth.linkedPassword, 'UniqueField42');
      expect(fixture.account.identity!.uid, 'synthetic-owner');
      expect(identical(fixture.account.accountStore, originalStore), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'provider collision displays safe error without replacing the account',
    (tester) async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      fixture.auth.failure = const AppFailure(
        'credential_in_use',
        'This Google account is already connected to another Unlabel account.',
      );
      await _open(tester, fixture);
      final originalStore = fixture.account.accountStore;
      await _tap(tester, find.text('Sign-in methods'));
      await _tap(tester, find.text('Connect Google'));
      expect(
        find.text(
          'This Google account is already connected to another Unlabel account.',
        ),
        findsOneWidget,
      );
      expect(fixture.account.identity!.uid, 'synthetic-owner');
      expect(fixture.account.identity!.providers, {'password'});
      expect(identical(fixture.account.accountStore, originalStore), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'profile settings windows remain usable at 320px/2x $brightness',
      (tester) async {
        final fixture = await _Fixture.create();
        addTearDown(fixture.dispose);
        await _open(
          tester,
          fixture,
          size: const Size(320, 760),
          brightness: brightness,
          textScale: 2,
        );
        for (final window in [
          ('Gender', 'Cancel'),
          ('Sign-in methods', 'Back'),
          ('Notifications', 'Close'),
          ('Privacy', 'Close'),
          ('Help', 'Close'),
        ]) {
          expect(find.text(window.$1), findsOneWidget, reason: window.$1);
          await _tap(tester, find.text(window.$1));
          expect(find.byType(Dialog), findsOneWidget);
          final footer = find.ancestor(
            of: find.text(window.$2),
            matching: find.byWidgetPredicate(
              (widget) => widget is ButtonStyleButton,
            ),
          );
          final rect = tester.getRect(footer);
          expect(rect.top, greaterThanOrEqualTo(0), reason: window.$1);
          expect(rect.bottom, lessThanOrEqualTo(760), reason: window.$1);
          expect(tester.takeException(), isNull, reason: window.$1);
          await _tap(tester, footer);
        }
        expect(fixture.auth.googleLinks + fixture.auth.passwordLinks, 0);
        expect(fixture.repository.writes, isEmpty);
      },
    );
  }
}
