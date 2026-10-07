import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/app/unlabel_app.dart';
import 'package:unlabel/core/accounts/account_auth.dart';
import 'package:unlabel/core/accounts/account_controller.dart';
import 'package:unlabel/core/accounts/account_data.dart';
import 'package:unlabel/core/accounts/account_store.dart';
import 'package:unlabel/core/accounts/account_sync_api.dart';
import 'package:unlabel/core/network/unlabel_repository.dart';
import 'package:unlabel/core/storage/local_store.dart';

class _Preferences implements PreferencesAdapter {
  final values = <String, String>{};
  bool failWrites = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('Synthetic storage failure');
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async => values.remove(key);
}

class _Auth extends AccountAuth {
  AccountIdentity? current;
  int signIns = 0;
  @override
  AccountIdentity? get identity => current;
  void setUser(String? uid) {
    current = uid == null
        ? null
        : AccountIdentity(uid: uid, email: '$uid@example.invalid');
    notifyListeners();
  }

  @override
  Future<void> start() async {}
  @override
  Future<void> signIn(String email, String password) async {
    signIns++;
    setUser('account-a');
  }

  @override
  Future<void> create(String email, String password) => signIn(email, password);
  @override
  Future<void> resetPassword(String email) async {}
  @override
  Future<void> signOut() async => setUser(null);
  @override
  Future<String> token(String expectedUid) async {
    if (identity?.uid != expectedUid) {
      throw StateError('Synthetic identity changed');
    }
    return expectedUid;
  }
}

class _Sync implements AccountSyncTransport {
  final accounts = <String, AccountSnapshot>{};
  int availabilityCalls = 0;
  final fetched = <String>[];
  final uploaded = <String>[];
  @override
  Future<bool> available() async {
    availabilityCalls++;
    return true;
  }

  @override
  Future<AccountSnapshot> fetch(String token) async {
    fetched.add(token);
    return accounts[token] ?? AccountSnapshot(revision: 0, data: AccountData());
  }

  @override
  Future<AccountSnapshot> put(String token, AccountMutation mutation) async {
    uploaded.add(token);
    final previous = accounts[token];
    if (mutation.expectedRevision != (previous?.revision ?? 0)) {
      throw const AppFailure('sync_conflict', 'Synthetic revision changed');
    }
    return accounts[token] = AccountSnapshot(
      revision: mutation.expectedRevision + 1,
      data: mutation.data,
      updatedAt: DateTime.utc(2026, 10, 7),
    );
  }

  @override
  void cancelAll() {}
  @override
  void close() {}
}

class _Repository extends UnlabelRepository {
  _Repository() : super(baseUrl: 'https://example.test');
  Future<ProductReport> Function(String)? loader;
  int loads = 0;
  @override
  Future<ProductReport> loadReport(String barcode) async {
    loads++;
    return loader == null ? _report('Guest scanned oats') : loader!(barcode);
  }
}

ProductReport _report(String name) {
  final raw = jsonDecode(
    File('../contracts/examples/label-report-v1.current.synthetic.json')
        .readAsStringSync(),
  ) as JsonMap;
  (raw['identity'] as JsonMap)['name'] = name;
  return ProductReport.fromJson(raw);
}

AccountData _data(String name) {
  final entry = AccountEntry(
    entryId: '11111111-1111-4111-8111-111111111111',
    recordedAt: DateTime.utc(2026, 10, 7),
    report: _report(name),
  );
  return AccountData(saved: [entry], history: [entry]);
}

AccountController _controller(_Auth auth, _Sync sync, LocalStore guest) {
  final controller = AccountController(
    auth: auth,
    api: sync,
    guestStore: guest,
    preferences: guest.preferences,
    debounce: const Duration(days: 1),
  );
  addTearDown(() {
    controller.dispose();
    auth.dispose();
    sync.close();
  });
  return controller;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
  });
  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  testWidgets('floating navigation clears safe areas and scrollable actions', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(bottom: 34);
    tester.view.padding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final settings in [(390.0, 1.0), (320.0, 2.0)]) {
      tester.view.physicalSize = Size(settings.$1, 844);
      tester.platformDispatcher.textScaleFactorTestValue = settings.$2;
      final guest = LocalStore(preferences: _Preferences());
      final auth = _Auth();
      final sync = _Sync();
      final repository = _Repository();
      addTearDown(repository.close);
      await tester.pumpWidget(
        UnlabelApp(
          repository: repository,
          store: guest,
          accountController: _controller(auth, sync, guest),
          showWelcome: false,
        ),
      );
      await tester.pumpAndSettle();
      final bar = tester.getRect(find.byKey(const Key('floating-navigation')));
      expect(bar.left, greaterThanOrEqualTo(16));
      expect(bar.right, lessThanOrEqualTo(settings.$1 - 16));
      expect(844 - 34 - bar.bottom, greaterThanOrEqualTo(12));
      expect(
        tester.getRect(find.byType(SingleChildScrollView).first).bottom,
        greaterThan(bar.bottom),
      );
      for (var index = 0; index < 4; index++) {
        final target = tester.getRect(find.byKey(Key('mobile-nav-$index')));
        expect(target.width, greaterThanOrEqualTo(48));
        expect(target.height, greaterThanOrEqualTo(48));
      }
      expect(find.byKey(const Key('mobile-nav-4')), findsNothing);
      final profile = tester.getSize(find.byTooltip('Profile'));
      expect(profile.width, greaterThanOrEqualTo(48));
      expect(profile.height, greaterThanOrEqualTo(48));
      final source = find.text('Know where facts come from');
      final position = Scrollable.of(tester.element(source)).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      final sourceCard = tester.getRect(
        find.ancestor(of: source, matching: find.byType(Card)).first,
      );
      expect(sourceCard.bottom, lessThanOrEqualTo(bar.top - 16));
      await tester.ensureVisible(source);
      await tester.pumpAndSettle();
      expect(source.hitTestable(), findsOneWidget);
      expect(tester.getRect(source).bottom, lessThan(bar.top));
      expect(sync.uploaded, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('input keyboard hides floating navigation until dismissed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final guest = LocalStore(preferences: _Preferences());
    final auth = _Auth();
    final sync = _Sync();
    final repository = _Repository();
    addTearDown(repository.close);
    await tester.pumpWidget(
      UnlabelApp(
        repository: repository,
        store: guest,
        accountController: _controller(auth, sync, guest),
        showWelcome: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('floating-navigation')), findsOneWidget);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('floating-navigation')), findsNothing);
    expect(find.byTooltip('Profile'), findsOneWidget);
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('floating-navigation')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigation feedback follows changed selections once', (
    tester,
  ) async {
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final guest = LocalStore(preferences: _Preferences());
    final auth = _Auth();
    final sync = _Sync();
    final repository = _Repository();
    addTearDown(repository.close);
    await tester.pumpWidget(
      UnlabelApp(
        repository: repository,
        store: guest,
        accountController: _controller(auth, sync, guest),
        showWelcome: false,
      ),
    );
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const Key('mobile-nav-0')));
    expect(haptics, isEmpty);
    await _tap(tester, find.byKey(const Key('mobile-nav-1')));
    expect(find.text('Scan Label'), findsOneWidget);
    expect(haptics, ['HapticFeedbackType.selectionClick']);
    await _tap(tester, find.byKey(const Key('mobile-nav-1')));
    expect(haptics, ['HapticFeedbackType.selectionClick']);
    await _tap(tester, find.byKey(const Key('mobile-nav-3')));
    expect(find.text('Saved products'), findsOneWidget);
    expect(haptics, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick',
    ]);
    expect(sync.uploaded, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'onboarding is optional-account and remembered after continuing',
    (tester) async {
      final preferences = _Preferences();
      final guest = LocalStore(preferences: preferences);
      await guest.record(_report('Existing guest oats'));
      final auth = _Auth();
      final sync = _Sync();
      final controller = _controller(auth, sync, guest);
      final repository = _Repository();
      addTearDown(repository.close);
      Widget app() => UnlabelApp(
        repository: repository,
        store: guest,
        accountController: controller,
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(
        find.text('A little clarity for\nevery food find.'),
        findsOneWidget,
      );
      expect(
        find.text('No account needed. Sign in for other devices.'),
        findsOneWidget,
      );
      expect(sync.availabilityCalls, 0);
      expect(sync.uploaded, isEmpty);
      expect(auth.signIns, 0);
      await _tap(tester, find.byKey(const Key('welcome-continue')));
      expect(find.text('Scan your\nfood label'), findsOneWidget);
      expect(find.text('Existing guest oats'), findsOneWidget);
      expect(await guest.welcomeCompleted(), true);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('welcome-continue')), findsNothing);
      expect(find.text('Existing guest oats'), findsOneWidget);
      expect((await guest.history()).single.report.name, 'Existing guest oats');
      expect(sync.fetched, isEmpty);
      expect(sync.uploaded, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed onboarding persistence still permits full guest use', (
    tester,
  ) async {
    final preferences = _Preferences()..failWrites = true;
    final guest = LocalStore(preferences: preferences);
    final auth = _Auth();
    final sync = _Sync();
    final controller = _controller(auth, sync, guest);
    final repository = _Repository();
    addTearDown(repository.close);
    await tester.pumpWidget(
      UnlabelApp(
        repository: repository,
        store: guest,
        accountController: controller,
      ),
    );
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const Key('welcome-continue')));
    expect(find.text('Scan your\nfood label'), findsOneWidget);
    expect(
      find.textContaining('Welcome could not be remembered'),
      findsOneWidget,
    );
    expect(await guest.welcomeCompleted(), false);
    await _tap(tester, find.byKey(const Key('mobile-nav-1')));
    expect(find.text('Scan Label'), findsOneWidget);
    expect(sync.uploaded, isEmpty);
    expect(auth.signIns, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'guest barcode and saved workflows make no private sync requests',
    (tester) async {
      final guest = LocalStore(preferences: _Preferences());
      final auth = _Auth();
      final sync = _Sync();
      final controller = _controller(auth, sync, guest);
      final repository = _Repository();
      addTearDown(repository.close);
      await tester.pumpWidget(
        UnlabelApp(
          repository: repository,
          store: guest,
          accountController: controller,
          showWelcome: false,
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Barcode Scan'));
      await tester.enterText(
        find.byKey(const Key('lookup-input')),
        '0123456789012',
      );
      await _tap(tester, find.byKey(const Key('lookup-submit')));
      expect(find.text('Guest scanned oats'), findsOneWidget);
      expect((await guest.history()).single.report.name, 'Guest scanned oats');
      await _tap(tester, find.byKey(const Key('save-report')));
      expect((await guest.saved()).single.report.name, 'Guest scanned oats');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const Key('mobile-nav-3')));
      expect(find.text('Guest scanned oats'), findsOneWidget);
      await _tap(tester, find.byTooltip('Profile'));
      expect(find.text('Sign in'), findsOneWidget);
      await _tap(tester, find.text('Continue as guest'));
      expect(find.text('Saved products'), findsOneWidget);
      expect(find.text('Guest scanned oats'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('mobile-nav-0')));
      expect(find.text('Scan your\nfood label'), findsOneWidget);
      expect(auth.signIns, 0);
      expect(sync.availabilityCalls, 0);
      expect(sync.fetched, isEmpty);
      expect(sync.uploaded, isEmpty);
      expect(repository.loads, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'identity switch closes old reports and selects the isolated library',
    (tester) async {
      final preferences = _Preferences();
      final guest = LocalStore(preferences: preferences);
      await guest.save(_report('Guest private oats'));
      await guest.record(_report('Guest private oats'));
      final auth = _Auth()..setUser('account-a');
      final sync = _Sync();
      for (final name in ['account-a', 'account-b']) {
        final snapshot = AccountSnapshot(
          revision: 1,
          data: _data('Private $name oats'),
          updatedAt: DateTime.utc(2026, 10, 7),
        );
        sync.accounts[name] = snapshot;
        await AccountStore(
          uid: name,
          preferences: preferences,
        ).acceptCloud(snapshot, expectedLocalRevision: 0);
      }
      final controller = _controller(auth, sync, guest);
      await controller.start();
      await controller.refreshSync();
      final repository = _Repository();
      addTearDown(repository.close);
      await tester.pumpWidget(
        UnlabelApp(
          repository: repository,
          store: guest,
          accountController: controller,
          showWelcome: false,
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const Key('mobile-nav-3')));
      await _tap(tester, find.text('Private account-a oats'));
      expect(find.byKey(const Key('save-report')), findsOneWidget);
      auth.setUser('account-b');
      await tester.pumpAndSettle();
      await controller.refreshSync();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('save-report')), findsNothing);
      expect(find.text('Private account-a oats'), findsNothing);
      expect(find.text('Scan your\nfood label'), findsOneWidget);
      expect(find.text('Private account-b oats'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('mobile-nav-3')));
      expect(find.text('Private account-b oats'), findsOneWidget);
      expect(find.text('Private account-a oats'), findsNothing);
      expect(
        (await AccountStore(
          uid: 'account-a',
          preferences: preferences,
        ).saved()).single.report.name,
        'Private account-a oats',
      );
      expect(
        (await AccountStore(
          uid: 'account-b',
          preferences: preferences,
        ).saved()).single.report.name,
        'Private account-b oats',
      );
      auth.setUser(null);
      await tester.pumpAndSettle();
      expect(find.text('Guest private oats'), findsOneWidget);
      expect(find.text('Private account-b oats'), findsNothing);
      expect((await guest.saved()).single.report.name, 'Guest private oats');
      expect(sync.uploaded, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a late lookup cannot re-open an old owner report after switching',
    (tester) async {
      final guest = LocalStore(preferences: _Preferences());
      final auth = _Auth();
      final sync = _Sync();
      final controller = _controller(auth, sync, guest);
      final repository = _Repository();
      addTearDown(repository.close);
      final pending = Completer<ProductReport>();
      repository.loader = (_) => pending.future;
      await tester.pumpWidget(
        UnlabelApp(
          repository: repository,
          store: guest,
          accountController: controller,
          showWelcome: false,
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Barcode Scan'));
      await tester.enterText(
        find.byKey(const Key('lookup-input')),
        '0123456789012',
      );
      await tester.tap(find.byKey(const Key('lookup-submit')));
      await tester.pump();
      auth.setUser('account-a');
      await tester.pumpAndSettle();
      pending.complete(_report('Old guest response'));
      await tester.pumpAndSettle();
      expect(find.text('Old guest response'), findsNothing);
      expect(find.byKey(const Key('save-report')), findsNothing);
      expect(await guest.history(), isEmpty);
      expect(await controller.activeStore.history(), isEmpty);
      expect(find.text('Scan your\nfood label'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
