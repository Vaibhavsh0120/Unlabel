import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/app/unlabel_app.dart';
import 'package:unlabel/app/unlabel_theme.dart';
import 'package:unlabel/core/accounts/account_auth.dart';
import 'package:unlabel/core/accounts/account_controller.dart';
import 'package:unlabel/core/accounts/account_data.dart';
import 'package:unlabel/core/accounts/account_sync_api.dart';
import 'package:unlabel/core/network/unlabel_repository.dart';
import 'package:unlabel/core/storage/local_store.dart';
import 'package:unlabel/features/scanner/presentation/product_info_page.dart';
import 'package:unlabel/features/scanner/presentation/ui_components.dart';

class MemoryPreferences implements PreferencesAdapter {
  final values = <String, String>{};
  bool failWrite = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    if (failWrite) throw StateError('Synthetic local write failure');
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async => values.remove(key);
}

class FakeRepository extends UnlabelRepository {
  FakeRepository() : super(baseUrl: 'https://example.test');
  Future<ProductReport> Function(String)? reportLoader;
  Future<SearchPage> Function(String, String?)? searchLoader;
  int reportCalls = 0;
  final searchCalls = <(String, String?)>[];
  @override
  Future<ProductReport> loadReport(String barcode) async {
    reportCalls++;
    return reportLoader == null ? _report() : reportLoader!(barcode);
  }

  @override
  Future<SearchPage> search(String query, {String? cursor}) async {
    searchCalls.add((query, cursor));
    return searchLoader == null ? _search() : searchLoader!(query, cursor);
  }
}

class DelayedSavedStore extends LocalStore {
  DelayedSavedStore() : super(preferences: MemoryPreferences());
  final firstRead = Completer<List<LocalReport>>();
  bool _first = true;
  @override
  Future<List<LocalReport>> saved() {
    if (_first) {
      _first = false;
      return firstRead.future;
    }
    return super.saved();
  }
}

ProductReport _report({bool historical = false}) => ProductReport.fromJson(
  jsonDecode(
    File(
      '../contracts/examples/label-report-v1.${historical ? 'historical' : 'current'}.synthetic.json',
    ).readAsStringSync(),
  ) as JsonMap,
);

SearchPage _search({
  String status = 'ready',
  String? cursor,
  String name = 'Synthetic oats',
  String barcode = '0123456789012',
}) => SearchPage.fromJson({
  'schema_version': '1',
  'search_version': 'catalogue-search-v1',
  'status': status,
  'normalized_query': 'oat',
  'candidates': status == 'ready'
      ? [
          {
            'identity': {
              'barcode': barcode,
              'name': name,
              'brands': 'Synthetic brand',
              'quantity_text': '400 g',
            },
            'source_id': 'synthetic-source',
          },
        ]
      : [],
  'next_cursor': cursor,
  'matched_count': status == 'ready' ? 2 : 0,
  'ambiguous': status == 'ready',
  'warnings': [],
});

class _NoPrivateSync implements AccountSyncTransport {
  @override
  Future<bool> available() async => false;
  @override
  Future<AccountSnapshot> fetch(String token) async =>
      throw StateError('Guest must not fetch private data');
  @override
  Future<AccountSnapshot> put(String token, AccountMutation mutation) async =>
      throw StateError('Guest must not upload private data');
  @override
  void cancelAll() {}
  @override
  void close() {}
}

Widget _app({required FakeRepository repository, required LocalStore store}) {
  final auth = UnavailableAccountAuth();
  final account = AccountController(
    auth: auth,
    api: _NoPrivateSync(),
    guestStore: store,
    preferences: store.preferences,
  );
  addTearDown(() {
    account.dispose();
    auth.dispose();
  });
  return UnlabelApp(
    repository: repository,
    store: store,
    showWelcome: false,
    accountController: account,
  );
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _appearance(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Profile'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Dark mode'));
  await tester.tap(find.text('Dark mode'));
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

  testWidgets('home remains usable across sizes and saved themes', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final repository = FakeRepository();
    addTearDown(repository.close);
    for (final size in [
      const Size(320, 568),
      const Size(390, 844),
      const Size(844, 390),
      const Size(768, 1024),
      const Size(1024, 768),
      const Size(1440, 900),
      const Size(1728, 1117),
    ]) {
      for (final brightness in Brightness.values) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        final preferences = MemoryPreferences();
        await LocalStore(preferences: preferences)
            .setAppearance(brightness.name);
        await tester.pumpWidget(
          _app(
            repository: repository,
            store: LocalStore(preferences: preferences),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            size.width >= 1200
                ? 'Scan your food label'
                : 'Scan your\nfood label',
          ),
          findsOneWidget,
        );
        expect(find.text('Barcode Scan'), findsOneWidget);
        expect(find.byKey(const Key('start-lookup')), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(
          Theme.of(tester.element(find.text('Unlabel'))).brightness,
          brightness,
        );
        expect(repository.reportCalls, 0);
        expect(repository.searchCalls, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });

  testWidgets(
    'light is the first-use default and dark choice survives restart',
    (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final repository = FakeRepository();
      addTearDown(repository.close);
      final preferences = MemoryPreferences();
      await tester.pumpWidget(
        _app(
          repository: repository,
          store: LocalStore(preferences: preferences),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.text('Unlabel'))).brightness,
        Brightness.light,
      );
      await _appearance(tester);
      await tester.pumpAndSettle();
      expect(await LocalStore(preferences: preferences).appearance(), 'dark');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        _app(
          repository: repository,
          store: LocalStore(preferences: preferences),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mobile-nav-0')));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.text('Unlabel'))).brightness,
        Brightness.dark,
      );
    },
  );

  testWidgets('two-times text keeps home actions and lower content reachable', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    final repository = FakeRepository();
    addTearDown(repository.close);
    for (final size in [const Size(320, 568), const Size(568, 320)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        _app(
          repository: repository,
          store: LocalStore(preferences: MemoryPreferences()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final text in [
        'Barcode Scan',
        'Compare Products',
        'Saved Products',
        'Know where facts come from',
      ]) {
        await Scrollable.ensureVisible(
          tester.element(find.text(text)),
          alignment: 0,
        );
        await tester.pumpAndSettle();
        expect(find.text(text).hitTestable(), findsOneWidget);
        final navigation = tester.getRect(
          find.byKey(const Key('floating-navigation')),
        );
        expect(tester.getCenter(find.text(text)).dy, lessThan(navigation.top));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets(
    'appearance overrides system and icon attribution is accessible',
    (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final repository = FakeRepository();
      addTearDown(repository.close);
      await tester.pumpWidget(
        _app(
          repository: repository,
          store: LocalStore(preferences: MemoryPreferences()),
        ),
      );
      await _appearance(tester);
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mobile-nav-0')));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.text('Unlabel'))).brightness,
        Brightness.dark,
      );
      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Help'));
      await tester.tap(find.text('Help'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('About Unlabel').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Solar icons by 480 Design'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('saving waits for the initial saved status read', (tester) async {
    final store = DelayedSavedStore();
    await tester.pumpWidget(
      MaterialApp(
        theme: UnlabelTheme.forBrightness(Brightness.light),
        home: ProductInfoPage.report(
          report: _report(),
          store: store,
          onChanged: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Checking saved status…'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('save-report')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('save-report')));
    store.firstRead.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('Save on this device'), findsOneWidget);
    await tester.tap(find.byKey(const Key('save-report')));
    await tester.pumpAndSettle();
    expect(find.text('Saved · remove'), findsOneWidget);
    expect((await store.saved()).length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'current report keeps unknown allergens and the approximate original sugar basis',
    (tester) async {
      final store = LocalStore(preferences: MemoryPreferences());
      await tester.pumpWidget(
        MaterialApp(
          theme: UnlabelTheme.forBrightness(Brightness.light),
          home: ProductInfoPage.report(
            report: _report(),
            store: store,
            onChanged: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Confirmed label'), findsOneWidget);
      expect(find.textContaining('/100'), findsNothing);
      expect(find.text('About 3 sugar cubes'), findsOneWidget);
      expect(find.textContaining('Per serving (40 g)'), findsWidgets);
      // Allergen details now live on the explicit declaration tab. Exercise
      // that control before checking the original missing-information warning.
      await _tapVisible(tester, find.text('Allergens'));
      expect(find.text('Contains'), findsOneWidget);
      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('May contain'), findsOneWidget);
      expect(
        find.text('Not captured — check the current package.'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Missing allergen information does not mean allergy-safe',
        ),
        findsOneWidget,
      );
      await _tapVisible(tester, find.byKey(const Key('save-report')));
      expect(
        (await store.saved()).single.report.name,
        'Synthetic corrected oats',
      );
      expect(find.text('Saved · remove'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed local saving keeps the report open without claiming success',
    (tester) async {
      final store = LocalStore(
        preferences: MemoryPreferences()..failWrite = true,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: UnlabelTheme.forBrightness(Brightness.light),
          home: ProductInfoPage.report(
            report: _report(),
            store: store,
            onChanged: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-report')));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic corrected oats'), findsOneWidget);
      expect(find.textContaining('local saving failed'), findsOneWidget);
      expect(find.text('Save on this device'), findsOneWidget);
      expect(await store.saved(), isEmpty);
    },
  );

  testWidgets(
    'historical reports and independent history clearing keep evidence boundaries',
    (tester) async {
      final repository = FakeRepository();
      addTearDown(repository.close);
      final store = LocalStore(preferences: MemoryPreferences());
      await store.record(_report(historical: true));
      await store.save(_report(historical: true));
      await tester.pumpWidget(_app(repository: repository, store: store));
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.text('History').last);
      await tester.pumpAndSettle();
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Your history'), findsNothing);
      await tester.tap(find.text('Synthetic oats'));
      await tester.pumpAndSettle();
      expect(find.text('Dated catalogue facts'), findsOneWidget);
      expect(
        find.text('Dated facts may differ from your package.'),
        findsOneWidget,
      );
      expect(find.text('Recorded facts, not a health score.'), findsOneWidget);
      expect(
        find.text('Current claims need the current label'),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear history'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear history').last);
      await tester.pumpAndSettle();
      expect(await store.history(), isEmpty);
      expect((await store.saved()).length, 1);
      expect(find.text('No labels viewed yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a corrupt saved list can be cleared without removing history', (
    tester,
  ) async {
    final repository = FakeRepository();
    addTearDown(repository.close);
    final preferences = MemoryPreferences();
    final store = LocalStore(preferences: preferences);
    await store.record(_report());
    preferences.values[LocalStore.savedKey] = '{broken';
    await tester.pumpWidget(_app(repository: repository, store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved').last);
    await tester.pumpAndSettle();
    expect(find.text('Reports could not be loaded'), findsOneWidget);
    await tester.tap(find.text('Clear saved products'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(preferences.values[LocalStore.savedKey], '{broken');
    await tester.tap(find.text('Clear saved products'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear saved products').last);
    await tester.pumpAndSettle();
    expect(await store.saved(), isEmpty);
    expect((await store.history()).length, 1);
    expect(find.text('Keep a useful label close'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('partial local recovery explains skipped entries', (
    tester,
  ) async {
    final repository = FakeRepository();
    addTearDown(repository.close);
    final preferences = MemoryPreferences();
    preferences.values[LocalStore.savedKey] = jsonEncode({
      'schema_version': '1',
      'entries': [
        {'id': 'unreadable-synthetic'},
      ],
    });
    await tester.pumpWidget(
      _app(
        repository: repository,
        store: LocalStore(preferences: preferences),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved').last);
    await tester.pumpAndSettle();
    expect(find.text('Some local reports could not be opened'), findsOneWidget);
    expect(
      find.textContaining('unreadable local reports were skipped'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('enlarged report text stays readable on narrow screens', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await tester.pumpWidget(
      MaterialApp(
        theme: UnlabelTheme.forBrightness(Brightness.dark),
        home: ProductInfoPage.report(
          report: _report(),
          store: LocalStore(preferences: MemoryPreferences()),
          onChanged: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final text in ['Nutrition snapshot', 'Ingredients & allergens']) {
      await tester.ensureVisible(find.text(text));
      await tester.pumpAndSettle();
      expect(find.text(text).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await _tapVisible(tester, find.text('Allergens'));
    expect(find.text('Contains'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('May contain'), findsOneWidget);
    expect(
      find.text('Not captured — check the current package.'),
      findsOneWidget,
    );
    final nutrientEvidence = find.byKey(const Key('report-nutrient-evidence'));
    await _tapVisible(tester, nutrientEvidence);
    expect(find.text('Fibre'), findsOneWidget);
    expect(find.text('Added sugars'), findsOneWidget);
    expect(find.text('Observed 2026-10-07'), findsWidgets);
    expect(tester.takeException(), isNull);
    // Source rows inside the expanded nutrient disclosure share their label;
    // target the page section explicitly to verify it remains reachable.
    final sourceHeading = find.widgetWithText(
      SectionTitle,
      'Source references',
    );
    await tester.ensureVisible(sourceHeading);
    await tester.pumpAndSettle();
    expect(sourceHeading.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
