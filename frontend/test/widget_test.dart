import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/app/unlabel_app.dart';
import 'package:unlabel/app/unlabel_theme.dart';
import 'package:unlabel/core/network/unlabel_repository.dart';
import 'package:unlabel/core/storage/local_store.dart';
import 'package:unlabel/features/scanner/presentation/lookup_page.dart';
import 'package:unlabel/features/scanner/presentation/report_page.dart';

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

Widget _lookup(
  FakeRepository repository, {
  bool barcode = true,
  Future<void> Function(ProductReport)? onReport,
}) => MaterialApp(
  theme: UnlabelTheme.forBrightness(Brightness.light),
  home: LookupPage(
    repository: repository,
    barcodeMode: barcode,
    onOpenReport: onReport ?? (_) async {},
    onEnterLabel: () {},
  ),
);

void main() {
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
          UnlabelApp(
            repository: repository,
            store: LocalStore(preferences: preferences),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Understand your\nfood label'), findsOneWidget);
        expect(find.text('Barcode lookup'), findsOneWidget);
        expect(find.text('Enter a label'), findsOneWidget);
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
        UnlabelApp(
          repository: repository,
          store: LocalStore(preferences: preferences),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.text('Unlabel'))).brightness,
        Brightness.light,
      );
      await tester.tap(find.byKey(const Key('theme-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark').last);
      await tester.pumpAndSettle();
      expect(await LocalStore(preferences: preferences).appearance(), 'dark');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        UnlabelApp(
          repository: repository,
          store: LocalStore(preferences: preferences),
        ),
      );
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
        UnlabelApp(
          repository: repository,
          store: LocalStore(preferences: MemoryPreferences()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final text in [
        'Barcode lookup',
        'Search products',
        'Enter a label',
        'Know where facts come from',
      ]) {
        await tester.ensureVisible(find.text(text));
        await tester.pumpAndSettle();
        expect(find.text(text).hitTestable(), findsOneWidget);
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
        UnlabelApp(
          repository: repository,
          store: LocalStore(preferences: MemoryPreferences()),
        ),
      );
      await tester.tap(find.byKey(const Key('theme-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark').last);
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.text('Unlabel'))).brightness,
        Brightness.dark,
      );
      await tester.tap(find.byTooltip('About Unlabel'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Solar icons by 480 Design'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('barcode validates, shows honest loading and a catalogue miss', (
    tester,
  ) async {
    final repository = FakeRepository();
    addTearDown(repository.close);
    final pending = Completer<ProductReport>();
    repository.reportLoader = (_) => pending.future;
    await tester.pumpWidget(_lookup(repository));
    await tester.tap(find.byKey(const Key('lookup-submit')));
    await tester.pump();
    expect(
      find.text('Enter an 8, 12, 13 or 14 digit barcode.'),
      findsOneWidget,
    );
    expect(repository.reportCalls, 0);
    await tester.enterText(
      find.byKey(const Key('lookup-input')),
      '0123456789012',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(find.text('Looking up…'), findsOneWidget);
    expect(repository.reportCalls, 1);
    pending.completeError(
      const AppFailure('not_found', 'Synthetic barcode has no report.'),
    );
    await tester.pumpAndSettle();
    expect(find.text('No catalogue report for this code'), findsOneWidget);
    expect(find.text('Enter this package label'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'name search identities are explicit and paging retains the submitted query',
    (tester) async {
      final repository = FakeRepository();
      addTearDown(repository.close);
      repository.searchLoader = (_, cursor) async => cursor == null
          ? _search(cursor: 'next-page')
          : _search(name: 'Synthetic second oats', barcode: '0123456789013');
      await tester.pumpWidget(_lookup(repository, barcode: false));
      await tester.enterText(find.byKey(const Key('lookup-input')), 'oat');
      await tester.tap(find.byKey(const Key('lookup-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Choose a matching package'), findsOneWidget);
      expect(find.text('Synthetic oats'), findsOneWidget);
      expect(find.text('Barcode 0123456789012'), findsOneWidget);
      expect(
        find.textContaining('Names alone do not confirm identity'),
        findsOneWidget,
      );
      expect(repository.reportCalls, 0);
      await tester.enterText(
        find.byKey(const Key('lookup-input')),
        'changed input',
      );
      await tester.ensureVisible(find.text('Show more matches'));
      await tester.tap(find.text('Show more matches'));
      await tester.pumpAndSettle();
      expect(repository.searchCalls, [('oat', null), ('oat', 'next-page')]);
      expect(find.text('Synthetic second oats'), findsOneWidget);
      expect(find.text('Synthetic oats'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a new failed query cannot display the previous query products', (
    tester,
  ) async {
    final repository = FakeRepository();
    addTearDown(repository.close);
    repository.searchLoader = (query, _) async {
      if (query == 'new query') {
        throw const AppFailure('network', 'Synthetic connection failure.');
      }
      return _search();
    };
    await tester.pumpWidget(_lookup(repository, barcode: false));
    await tester.enterText(find.byKey(const Key('lookup-input')), 'oat');
    await tester.tap(find.byKey(const Key('lookup-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic oats'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('lookup-input')), 'new query');
    await tester.tap(find.byKey(const Key('lookup-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Lookup could not be completed'), findsOneWidget);
    expect(find.text('Synthetic oats'), findsNothing);
    expect(find.textContaining('shown'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing lookup mode discards a late search response', (
    tester,
  ) async {
    final repository = FakeRepository();
    addTearDown(repository.close);
    final pending = Completer<SearchPage>();
    repository.searchLoader = (_, _) => pending.future;
    await tester.pumpWidget(_lookup(repository, barcode: false));
    await tester.enterText(find.byKey(const Key('lookup-input')), 'oat');
    await tester.tap(find.byKey(const Key('lookup-submit')));
    await tester.pump();
    await tester.tap(find.text('Barcode'));
    await tester.pump();
    pending.complete(_search());
    await tester.pumpAndSettle();
    expect(find.text('Synthetic oats'), findsNothing);
    expect(find.text('Look up barcode'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty, too broad and unavailable searches are distinct', (
    tester,
  ) async {
    for (final entry in [
      ('not_found', 'No matches for “oat”'),
      ('refine_query', 'Narrow your search'),
      ('unavailable', 'Catalogue search is unavailable'),
    ]) {
      final repository = FakeRepository();
      repository.searchLoader = (_, _) async => _search(status: entry.$1);
      await tester.pumpWidget(_lookup(repository, barcode: false));
      await tester.enterText(find.byKey(const Key('lookup-input')), 'oat');
      await tester.tap(find.byKey(const Key('lookup-submit')));
      await tester.pumpAndSettle();
      expect(find.text(entry.$2), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      repository.close();
    }
  });

  testWidgets('saving waits for the initial saved status read', (tester) async {
    final store = DelayedSavedStore();
    await tester.pumpWidget(
      MaterialApp(
        theme: UnlabelTheme.forBrightness(Brightness.light),
        home: ReportPage(report: _report(), store: store, onChanged: () {}),
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
          home: ReportPage(report: _report(), store: store, onChanged: () {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Your confirmed package label'), findsOneWidget);
      expect(find.textContaining('/100'), findsNothing);
      expect(find.text('About 3 sugar cubes'), findsOneWidget);
      expect(find.textContaining('Per serving (40 g)'), findsWidgets);
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
      await tester.tap(find.byKey(const Key('save-report')));
      await tester.pumpAndSettle();
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
          home: ReportPage(report: _report(), store: store, onChanged: () {}),
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
      await tester.pumpWidget(UnlabelApp(repository: repository, store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('History').last);
      await tester.pumpAndSettle();
      expect(find.text('Your history'), findsOneWidget);
      await tester.tap(find.text('Synthetic oats'));
      await tester.pumpAndSettle();
      expect(find.text('Dated catalogue information'), findsOneWidget);
      expect(
        find.textContaining('may differ from the package'),
        findsOneWidget,
      );
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
    await tester.pumpWidget(UnlabelApp(repository: repository, store: store));
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
      UnlabelApp(
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
        home: ReportPage(
          report: _report(),
          store: LocalStore(preferences: MemoryPreferences()),
          onChanged: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final text in [
      'Nutrition snapshot',
      'Ingredients & allergens',
      'Sources & evidence',
    ]) {
      await tester.ensureVisible(find.text(text));
      await tester.pumpAndSettle();
      expect(find.text(text).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
