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
import 'package:unlabel/core/capture/live_barcode_scanner.dart';
import 'package:unlabel/core/storage/local_store.dart';
import 'package:unlabel/features/scanner/presentation/desktop_navigation.dart';
import 'package:unlabel/features/scanner/presentation/insights_page.dart';
import 'package:unlabel/features/scanner/presentation/library_page.dart';
import 'package:unlabel/features/scanner/presentation/product_info_page.dart';
import 'package:unlabel/features/scanner/presentation/sources_page.dart';

class _UnavailableScanner extends LiveBarcodeScanner {
  @override
  bool get ready => false;
  @override
  bool get busy => false;
  @override
  String? get error => 'No camera is connected to this test host.';
  @override
  Future<void> start() async {
    notifyListeners();
  }

  @override
  Future<void> stop() async {}
  @override
  Widget buildPreview() => const SizedBox.shrink();
}

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

class _SlowPreferences extends _Preferences {
  final restored = Completer<void>();
  @override
  Future<String?> read(String key) async {
    await restored.future;
    return super.read(key);
  }
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
  Future<SearchPage> search(String query, {String? cursor}) async =>
      SearchPage.fromJson({
        'schema_version': '1',
        'search_version': 'catalogue-search-v1',
        'status': 'ready',
        'normalized_query': query,
        'candidates': [
          {
            'identity': {
              'barcode': '0123456789012',
              'name': 'Guest scanned oats',
              'brands': 'Synthetic brand',
              'quantity_text': '400 g',
            },
            'source_id': 'synthetic-source',
          },
        ],
        'next_cursor': null,
        'matched_count': 1,
        'ambiguous': false,
        'warnings': [],
      });
  @override
  Future<ResearchSearchPage> searchResearch(
    String query, {
    String? cursor,
  }) async => ResearchSearchPage.empty();
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
  testWidgets(
    'desktop History and Saved switch content without moving the shell',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final guest = LocalStore(preferences: _Preferences());
      await guest.record(_report('History-only oats'));
      final repository = _Repository();
      addTearDown(repository.close);
      await tester.pumpWidget(
        UnlabelApp(
          barcodeScannerFactory: _UnavailableScanner.new,
          repository: repository,
          store: guest,
          accountController: _controller(_Auth(), _Sync(), guest),
          showWelcome: false,
        ),
      );
      await tester.pumpAndSettle();
      final sidebar = find.byKey(const Key('desktop-sidebar'));
      final header = find.byType(DesktopTopBar);
      final sidebarElement = tester.element(sidebar);
      final headerElement = tester.element(header);
      final sidebarBounds = tester.getRect(sidebar);
      final headerBounds = tester.getRect(header);
      final navigator = Navigator.of(sidebarElement);
      expect(navigator.canPop(), isFalse);

      for (final index in [4, 4, 3, 4, 0]) {
        await tester.tap(find.byKey(Key('desktop-nav-$index')));
        for (final elapsed in [
          Duration.zero,
          const Duration(milliseconds: 16),
          const Duration(milliseconds: 100),
        ]) {
          await tester.pump(elapsed);
          expect(tester.element(sidebar), same(sidebarElement));
          expect(tester.element(header), same(headerElement));
          expect(tester.getRect(sidebar), sidebarBounds);
          expect(tester.getRect(header), headerBounds);
          expect(
            navigator.canPop(),
            isFalse,
            reason: 'a primary destination must not push a second entire shell',
          );
        }
        await tester.pumpAndSettle();
        if (index == 4) {
          expect(
            tester.widget<LibraryPage>(find.byType(LibraryPage)).saved,
            isFalse,
          );
          expect(find.text('History-only oats'), findsOneWidget);
        } else if (index == 3) {
          expect(
            tester.widget<LibraryPage>(find.byType(LibraryPage)).saved,
            isTrue,
          );
          expect(find.text('History-only oats'), findsNothing);
        }
      }
      await tester.tap(find.byKey(const Key('desktop-nav-4')));
      await tester.pumpAndSettle();
      await _tap(tester, find.text('History-only oats'));
      final reportRoute =
          ModalRoute.of(tester.element(find.byType(ProductInfoPage)))!
              as PageRoute<void>;
      expect(reportRoute.transitionDuration, Duration.zero);
      expect(reportRoute.reverseTransitionDuration, Duration.zero);
      await tester.tap(find.widgetWithText(TextButton, 'History'));
      await tester.pump();
      expect(find.byType(ProductInfoPage), findsNothing);
      expect(tester.element(sidebar), same(sidebarElement));
      expect(tester.getRect(header), headerBounds);
      await tester.tap(find.byKey(const Key('desktop-nav-3')));
      await tester.pump();
      expect(tester.element(sidebar), same(sidebarElement));
      expect(tester.getRect(sidebar), sidebarBounds);
      expect(tester.getRect(header), headerBounds);
      expect(navigator.canPop(), isFalse);
      await tester.pumpAndSettle();
      expect(
        tester.widget<LibraryPage>(find.byType(LibraryPage)).saved,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('mobile History remains a separate page with Back to Home', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final guest = LocalStore(preferences: _Preferences());
    final repository = _Repository();
    addTearDown(repository.close);
    await tester.pumpWidget(
      UnlabelApp(
        barcodeScannerFactory: _UnavailableScanner.new,
        repository: repository,
        store: guest,
        accountController: _controller(_Auth(), _Sync(), guest),
        showWelcome: false,
      ),
    );
    await tester.pumpAndSettle();
    await _tap(tester, find.text('History').hitTestable());
    expect(tester.widget<LibraryPage>(find.byType(LibraryPage)).saved, isFalse);
    expect(
      tester.widget<LibraryPage>(find.byType(LibraryPage)).showTitle,
      isFalse,
    );
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Your history'), findsNothing);
    expect(
      find.text(
        'Stored on this device. These reports are snapshots of what you viewed.',
      ),
      findsOneWidget,
    );
    expect(find.byType(BackButton), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-insight-carousel')), findsOneWidget);
    expect(find.byKey(const Key('mobile-nav-3')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Insights retains desktop shell and returns to Home', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final guest = LocalStore(preferences: _Preferences());
    final auth = _Auth();
    final sync = _Sync();
    final repository = _Repository();
    addTearDown(repository.close);
    await tester.pumpWidget(
      UnlabelApp(
        barcodeScannerFactory: _UnavailableScanner.new,
        repository: repository,
        store: guest,
        accountController: _controller(auth, sync, guest),
        showWelcome: false,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('desktop-nav-5')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('desktop-sidebar')), findsOneWidget);
    expect(find.byKey(const Key('insight-featured')), findsOneWidget);
    expect(find.byTooltip('Search products'), findsNothing);
    expect(
      find.text('Search for a product, brand or ingredient...'),
      findsOneWidget,
    );
    final selected = tester.widget<Semantics>(
      find
          .ancestor(
            of: find.byKey(const Key('desktop-nav-5')),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(selected.properties.selected, isTrue);
    await tester.tap(find.byKey(const Key('desktop-brand-home')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-insight-carousel')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final width in [390.0, 1440.0]) {
    testWidgets('Sources uses root content and returns Home at $width px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final guest = LocalStore(preferences: _Preferences());
      final repository = _Repository();
      addTearDown(repository.close);
      await tester.pumpWidget(
        UnlabelApp(
          barcodeScannerFactory: _UnavailableScanner.new,
          repository: repository,
          store: guest,
          accountController: _controller(_Auth(), _Sync(), guest),
          showWelcome: false,
        ),
      );
      await tester.pumpAndSettle();
      final header = width >= 1200
          ? find.byType(DesktopTopBar)
          : find.byType(AppBar).hitTestable();
      final headerBounds = tester.getRect(header);
      final headerElement = tester.element(header);
      await _tap(
        tester,
        find.text(
          width >= 1200
              ? 'Data from package labels, manufacturer websites and Open Food Facts'
              : 'Know where facts come from',
        ),
      );
      expect(
        tester.widget<SourcesPage>(find.byType(SourcesPage)).embedded,
        isTrue,
      );
      expect(find.text('Our Sources'), findsOneWidget);
      expect(tester.element(header), same(headerElement));
      expect(tester.getRect(header), headerBounds);
      expect(Navigator.of(tester.element(header)).canPop(), isFalse);
      if (width >= 1200) {
        expect(find.byKey(const Key('desktop-sidebar')), findsOneWidget);
      } else {
        expect(find.byKey(const Key('floating-navigation')), findsNothing);
      }
      if (width >= 1200) {
        expect(find.byType(BackButton), findsNothing);
        await _tap(tester, find.byKey(const Key('desktop-nav-0')));
      } else {
        expect(find.byType(BackButton), findsOneWidget);
        await _tap(tester, find.byType(BackButton));
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home-insight-carousel')), findsOneWidget);
      if (width >= 1200) {
        await tester.tap(find.byKey(const Key('desktop-nav-5')));
        await tester.pumpAndSettle();
      } else {
        await _tap(tester, find.text('See all').first);
        expect(find.text('Insights'), findsOneWidget);
      }
      await _tap(tester, find.text('Where the facts come from'));
      expect(find.text('Our Sources'), findsOneWidget);
      if (width >= 1200) {
        expect(find.byType(BackButton), findsNothing);
        await _tap(tester, find.byKey(const Key('desktop-nav-5')));
      } else {
        await _tap(tester, find.byType(BackButton));
      }
      expect(find.byType(InsightsPage), findsOneWidget);
      expect(find.byType(SourcesPage), findsNothing);
      expect(tester.element(header), same(headerElement));
      expect(tester.getRect(header), headerBounds);
      if (width < 1200) expect(find.text('Insights'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      'unknown link renders its shell before local restore at $width px',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.defaultRouteNameTestValue = '/missing/deep';
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
        final preferences = _SlowPreferences();
        final guest = LocalStore(preferences: preferences);
        final repository = _Repository();
        addTearDown(repository.close);
        await tester.pumpWidget(
          UnlabelApp(
            barcodeScannerFactory: _UnavailableScanner.new,
            repository: repository,
            store: guest,
            accountController: _controller(_Auth(), _Sync(), guest),
          ),
        );
        expect(find.text('Page not found'), findsOneWidget);
        if (width >= 1200) {
          expect(find.byType(DesktopTopBar), findsOneWidget);
          expect(find.byKey(const Key('desktop-sidebar')), findsOneWidget);
        } else {
          expect(find.byKey(const Key('mobile-brand-home')), findsOneWidget);
          expect(find.byKey(const Key('floating-navigation')), findsOneWidget);
        }
        await tester.tap(find.widgetWithText(FilledButton, 'Go to Home'));
        await tester.pump();
        expect(find.byKey(const Key('home-insight-carousel')), findsOneWidget);
        preferences.restored.complete();
        await tester.pumpAndSettle();
        expect(find.text('Page not found'), findsNothing);
        expect(find.byKey(const Key('welcome-continue')), findsNothing);
        expect(find.byKey(const Key('home-insight-carousel')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('unknown initial link keeps working shell at $width px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.defaultRouteNameTestValue = '/missing/deep';
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
      final guest = LocalStore(preferences: _Preferences());
      final repository = _Repository();
      addTearDown(repository.close);
      await tester.pumpWidget(
        UnlabelApp(
          barcodeScannerFactory: _UnavailableScanner.new,
          repository: repository,
          store: guest,
          accountController: _controller(_Auth(), _Sync(), guest),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Page not found'), findsOneWidget);
      if (width >= 1200) {
        expect(find.byType(DesktopTopBar), findsOneWidget);
        expect(find.byKey(const Key('desktop-sidebar')), findsOneWidget);
        expect(
          find.byKey(const Key('not-found-desktop-content')),
          findsOneWidget,
        );
      } else {
        expect(find.byKey(const Key('mobile-brand-home')), findsOneWidget);
        expect(find.byKey(const Key('floating-navigation')), findsOneWidget);
        expect(
          find.byKey(const Key('navigation-active-indicator')),
          findsNothing,
        );
      }
      await _tap(tester, find.widgetWithText(FilledButton, 'Go to Home'));
      expect(find.text('Page not found'), findsNothing);
      expect(find.byKey(const Key('home-insight-carousel')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'recovered initial missing route stays Home across account changes',
    (tester) async {
      tester.platformDispatcher.defaultRouteNameTestValue = '/missing/deep';
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
      final guest = LocalStore(preferences: _Preferences());
      final auth = _Auth();
      final sync = _Sync();
      final repository = _Repository();
      addTearDown(repository.close);
      await tester.pumpWidget(
        UnlabelApp(
          barcodeScannerFactory: _UnavailableScanner.new,
          repository: repository,
          store: guest,
          accountController: _controller(auth, sync, guest),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Page not found'), findsOneWidget);
      await _tap(tester, find.widgetWithText(FilledButton, 'Go to Home'));
      expect(find.byKey(const Key('home-insight-carousel')), findsOneWidget);
      for (final uid in ['account-a', 'account-b', null]) {
        auth.setUser(uid);
        await tester.pumpAndSettle();
        expect(find.text('Page not found'), findsNothing);
        expect(find.byKey(const Key('home-insight-carousel')), findsOneWidget);
      }
      unawaited(
        Navigator.of(tester.element(find.byKey(const Key('mobile-brand-home'))))
            .pushNamed('/another-missing-link'),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Page not found'),
        findsOneWidget,
        reason: 'recovering one route must not hide later unknown routes',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('mobile brand returns from Saved to Home', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final guest = LocalStore(preferences: _Preferences());
    final repository = _Repository();
    addTearDown(repository.close);
    await tester.pumpWidget(
      UnlabelApp(
        barcodeScannerFactory: _UnavailableScanner.new,
        repository: repository,
        store: guest,
        accountController: _controller(_Auth(), _Sync(), guest),
        showWelcome: false,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mobile-nav-3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-insight-carousel')), findsNothing);
    await tester.tap(find.byKey(const Key('mobile-brand-home')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-insight-carousel')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'an unknown pushed route can recover and navigate its own shell',
    (tester) async {
      final guest = LocalStore(preferences: _Preferences());
      final repository = _Repository();
      addTearDown(repository.close);
      await tester.pumpWidget(
        UnlabelApp(
          barcodeScannerFactory: _UnavailableScanner.new,
          repository: repository,
          store: guest,
          accountController: _controller(_Auth(), _Sync(), guest),
          showWelcome: false,
        ),
      );
      await tester.pumpAndSettle();
      unawaited(
        Navigator.of(tester.element(find.byKey(const Key('mobile-brand-home'))))
            .pushNamed('/missing'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Page not found'), findsOneWidget);
      await tester.tap(find.byKey(const Key('mobile-nav-3')));
      await tester.pumpAndSettle();
      expect(find.text('Page not found'), findsNothing);
      await tester.tap(find.byKey(const Key('mobile-brand-home')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home-insight-carousel')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('History and saved Insight readers retain desktop shell', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final guest = LocalStore(preferences: _Preferences());
    final repository = _Repository();
    addTearDown(repository.close);
    await tester.pumpWidget(
      UnlabelApp(
        barcodeScannerFactory: _UnavailableScanner.new,
        repository: repository,
        store: guest,
        accountController: _controller(_Auth(), _Sync(), guest),
        showWelcome: false,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('desktop-nav-4')));
    await tester.pumpAndSettle();
    expect(find.byType(DesktopTopBar), findsOneWidget);
    expect(find.byKey(const Key('desktop-sidebar')), findsOneWidget);
    expect(find.text('History'), findsWidgets);
    await tester.tap(find.byKey(const Key('desktop-nav-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-insight-carousel')), findsOneWidget);
    await tester.tap(find.byKey(const Key('desktop-nav-5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('insight-featured')));
    await tester.pumpAndSettle();
    expect(find.byType(InsightArticlePage), findsOneWidget);
    expect(find.byType(DesktopTopBar), findsOneWidget);
    expect(find.byKey(const Key('desktop-sidebar')), findsOneWidget);
    final article = tester
        .widget<InsightArticlePage>(find.byType(InsightArticlePage))
        .article;
    await tester.tap(find.byKey(Key('insight-save-${article.id}')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const Key('insights-see-saved')));
    expect(find.byType(DesktopTopBar), findsOneWidget);
    await tester.tap(find.byKey(Key('insight-card-${article.id}')));
    await tester.pumpAndSettle();
    expect(find.byType(InsightArticlePage), findsOneWidget);
    expect(find.byType(DesktopTopBar), findsOneWidget);
    expect(find.byKey(const Key('desktop-sidebar')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Saved insights'), findsOneWidget);
    await tester.tap(find.byKey(const Key('desktop-brand-home')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-insight-carousel')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  setUp(() {
    // Widget tests retain the packages' MethodChannel implementations, rather
    // than registering the Android Pigeon implementations. Complete both
    // recovery and camera discovery so scanner fallback is deterministic.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/image_picker'),
          (call) async {
            if (call.method == 'retrieve') return null;
            throw MissingPluginException();
          },
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/camera'),
          (call) async {
            if (call.method == 'availableCameras') return <Object>[];
            throw MissingPluginException();
          },
        );
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/camera'),
          null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/image_picker'),
          null,
        );
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
          barcodeScannerFactory: _UnavailableScanner.new,
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
      expect(844 - 34 - bar.bottom, closeTo(2, .01));
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

  testWidgets(
    'Home search is mounted before tap and receives immediate focus',
    (tester) async {
      final guest = LocalStore(preferences: _Preferences());
      final auth = _Auth();
      final sync = _Sync();
      final repository = _Repository();
      addTearDown(repository.close);
      await tester.pumpWidget(
        UnlabelApp(
          barcodeScannerFactory: _UnavailableScanner.new,
          repository: repository,
          store: guest,
          accountController: _controller(auth, sync, guest),
          showWelcome: false,
        ),
      );
      await tester.pumpAndSettle();
      final input = find.byKey(
        const Key('product-search-input'),
        skipOffstage: false,
      );
      expect(input, findsOneWidget);
      final focus = tester.widget<TextField>(input).focusNode!;
      expect(focus.hasFocus, isFalse);
      await tester.tap(find.byTooltip('Search products'));
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      expect(find.byKey(const Key('product-search-input')), findsOneWidget);
      expect(find.byTooltip('Profile'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(focus.hasFocus, isFalse);
      expect(find.byTooltip('Profile'), findsOneWidget);
    },
  );

  testWidgets('mobile Scan retains the shared app header and working actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final guest = LocalStore(preferences: _Preferences());
    final repository = _Repository();
    addTearDown(repository.close);
    await tester.pumpWidget(
      UnlabelApp(
        barcodeScannerFactory: _UnavailableScanner.new,
        repository: repository,
        store: guest,
        accountController: _controller(_Auth(), _Sync(), guest),
        showWelcome: false,
      ),
    );
    await tester.pumpAndSettle();
    final homeHeader = tester.widget<AppBar>(find.byType(AppBar).first);
    await _tap(tester, find.byKey(const Key('mobile-nav-1')));
    expect(find.text('Scan Label'), findsOneWidget);
    expect(find.byKey(const Key('mobile-brand-home')), findsOneWidget);
    expect(
      tester.widget<AppBar>(find.byType(AppBar).first).toolbarHeight,
      homeHeader.toolbarHeight,
    );
    expect(find.byTooltip('Search products'), findsOneWidget);
    expect(find.byTooltip('Profile'), findsOneWidget);
    await _tap(tester, find.byTooltip('Search products'));
    expect(find.byKey(const Key('product-search-input')), findsOneWidget);
    await _tap(tester, find.byTooltip('Close search'));
    expect(find.text('Scan Label'), findsOneWidget);
    await _tap(tester, find.byTooltip('Profile'));
    expect(find.text('Sign in'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const Key('mobile-brand-home')));
    expect(find.text('Scan your\nfood label'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
        barcodeScannerFactory: _UnavailableScanner.new,
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
        barcodeScannerFactory: _UnavailableScanner.new,
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
        barcodeScannerFactory: _UnavailableScanner.new,
        repository: repository,
        store: guest,
        accountController: controller,
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Scan food smarter'), findsOneWidget);
      expect(find.text('I already have an account'), findsOneWidget);
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
        barcodeScannerFactory: _UnavailableScanner.new,
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
    'guest search and saved workflows make no private sync requests',
    (tester) async {
      final guest = LocalStore(preferences: _Preferences());
      final auth = _Auth();
      final sync = _Sync();
      final controller = _controller(auth, sync, guest);
      final repository = _Repository();
      addTearDown(repository.close);
      await tester.pumpWidget(
        UnlabelApp(
          barcodeScannerFactory: _UnavailableScanner.new,
          repository: repository,
          store: guest,
          accountController: controller,
          showWelcome: false,
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.byTooltip('Search products'));
      await tester.enterText(
        find.byKey(const Key('product-search-input')),
        'Oats',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Guest scanned oats').first);
      expect(find.text('Guest scanned oats').hitTestable(), findsOneWidget);
      expect((await guest.history()).single.report.name, 'Guest scanned oats');
      await _tap(tester, find.byKey(const Key('save-report')));
      expect((await guest.saved()).single.report.name, 'Guest scanned oats');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tap(tester, find.byTooltip('Close search'));
      await _tap(tester, find.byKey(const Key('mobile-nav-3')));
      expect(find.text('Guest scanned oats').hitTestable(), findsOneWidget);
      await _tap(tester, find.byTooltip('Profile'));
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Continue as guest'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Saved products'), findsOneWidget);
      expect(find.text('Guest scanned oats').hitTestable(), findsOneWidget);
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
          barcodeScannerFactory: _UnavailableScanner.new,
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
          barcodeScannerFactory: _UnavailableScanner.new,
          repository: repository,
          store: guest,
          accountController: controller,
          showWelcome: false,
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.byTooltip('Search products'));
      await tester.enterText(
        find.byKey(const Key('product-search-input')),
        'Oats',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guest scanned oats').first);
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
