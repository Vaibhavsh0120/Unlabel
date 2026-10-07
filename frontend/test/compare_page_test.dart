import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/app/unlabel_theme.dart';
import 'package:unlabel/core/network/unlabel_repository.dart';
import 'package:unlabel/core/storage/local_store.dart';
import 'package:unlabel/features/scanner/presentation/compare_page.dart';

class _MemoryPreferences implements PreferencesAdapter {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
}

class _Repository extends UnlabelRepository {
  _Repository() : super(baseUrl: 'https://example.test');
  Future<ProductReport> Function(String)? loader;
  final calls = <String>[];
  @override
  Future<ProductReport> loadReport(String barcode) async {
    calls.add(barcode);
    return loader == null ? _current(name: 'Barcode oats') : loader!(barcode);
  }
}

JsonMap _fixture({bool historical = false}) => jsonDecode(
  File(
    '../contracts/examples/label-report-v1.${historical ? 'historical' : 'current'}.synthetic.json',
  ).readAsStringSync(),
) as JsonMap;

ProductReport _current({
  String name = 'Oats A',
  double? sugar = 12,
  JsonMap? basis,
  String preparation = 'as_sold',
  String unit = 'g',
  List<JsonMap>? rows,
}) {
  final raw = _fixture();
  (raw['identity'] as JsonMap)['name'] = name;
  final originals = (raw['nutrition'] as JsonMap)['original_rows'] as List;
  final row = originals.single as JsonMap;
  row['value'] = sugar;
  row['unit'] = unit;
  row['basis'] = basis ?? {'kind': 'serving', 'amount': 40.0, 'unit': 'g'};
  row['preparation'] = preparation;
  if (rows != null) (raw['nutrition'] as JsonMap)['original_rows'] = rows;
  return ProductReport.fromJson(raw);
}

ComparisonTable _table({
  JsonMap? basis,
  String? preparation = 'as_sold',
  double? value = 12,
  String unit = 'g',
}) => ComparisonTable(
  id: 'synthetic',
  basis: basis ?? {'kind': 'serving', 'amount': 40.0, 'unit': 'g'},
  preparation: preparation,
  values: {'sugars': ComparisonValue(value, unit)},
);

NutritionComparison _sugar(ComparisonTable? a, ComparisonTable? b) =>
    compareTables(a, b).singleWhere((row) => row.name == 'sugars');

Widget _screen(
  LocalStore store,
  _Repository repository, {
  Brightness brightness = Brightness.light,
  double textScale = 1,
  ValueChanged<ProductReport>? onOpen,
}) => MaterialApp(
  theme: UnlabelTheme.forBrightness(brightness),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(
    body: ComparePage(
      store: store,
      repository: repository,
      onOpenReport: onOpen,
    ),
  ),
);

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _pick(WidgetTester tester, String side, String product) async {
  await _tapVisible(tester, find.text('Choose $side'));
  await _tapVisible(tester, find.widgetWithText(ListTile, product));
}

void main() {
  test('compares original serving values without normalized substitution', () {
    final a = _current();
    final b = _current(name: 'Oats B', sugar: 9);
    expect(a.nutrients.singleWhere((row) => row.name == 'sugars').value, 30);
    final table = comparisonTables(a).single;
    expect(table.label, 'Per serving (40 g) · as sold');
    expect(table.values['sugars']!.value, 12);
    final comparison = _sugar(table, comparisonTables(b).single);
    expect(comparison.difference, -3);
    expect(comparison.summary, '3 g more in A');
    expect(_sugar(_table(), _table()).summary, 'Same amount');
  });

  test('basis, serving size, preparation and units must all match', () {
    final left = _table();
    for (final right in [
      _table(basis: {'kind': 'quantity', 'amount': 40, 'unit': 'g'}),
      _table(basis: {'kind': 'serving', 'amount': 50, 'unit': 'g'}),
      _table(basis: {'kind': 'serving', 'amount': null, 'unit': null}),
      _table(basis: {'kind': 'serving', 'amount': 40, 'unit': 'mL'}),
      _table(preparation: 'as_prepared'),
      _table(preparation: null),
      _table(unit: 'mg'),
    ]) {
      final row = _sugar(left, right);
      expect(row.difference, isNull);
      expect(row.summary, 'Different units or table basis');
    }
    final unknown = _table(
      basis: {'kind': 'serving', 'amount': null, 'unit': null},
    );
    expect(_sugar(unknown, unknown).difference, isNull);
    expect(
      _sugar(left, _table(value: null)).summary,
      'More label information needed',
    );
    expect(_sugar(left, _table(value: null)).right.label, 'Unknown');
    expect(_sugar(left, null).difference, isNull);
    // Equal integer/float quantities are compatible without display rounding.
    expect(
      _sugar(
        left,
        _table(basis: {'kind': 'serving', 'amount': 40, 'unit': 'g'}),
      ).difference,
      0,
    );
    expect(
      _sugar(
        left,
        _table(basis: {'kind': 'serving', 'amount': 40.001, 'unit': 'g'}),
      ).difference,
      isNull,
    );
  });

  test('contradictory duplicate rows suppress values; malformed rows suppress table', () {
    final originals =
        ((_fixture()['nutrition'] as JsonMap)['original_rows'] as List);
    final first = originals.single as JsonMap;
    final different = {...first, 'row_id': 'second', 'value': 7};
    final table = comparisonTables(_current(rows: [first, different])).single;
    expect(table.values['sugars']!.value, isNull);
    expect(table.values['sugars']!.label, 'Conflicting values');
    expect(
      _sugar(table, _table()).summary,
      'Conflicting facts need correction',
    );
    expect(
      comparisonTables(
        _current(
          rows: [
            first,
            {...first, 'value': double.nan},
          ],
        ),
      ),
      isEmpty,
    );
    expect(
      comparisonTables(
        _current(
          rows: [
            {...first, 'unit': 'kJ'},
          ],
        ),
      ),
      isEmpty,
    );
    expect(
      comparisonTables(
        _current(
          rows: [
            {...first, 'preparation': 3},
          ],
        ),
      ),
      isEmpty,
    );
    expect(
      comparisonTables(
        _current(
          rows: [
            {
              ...first,
              'basis': {'kind': 'quantity', 'amount': null, 'unit': null},
            },
          ],
        ),
      ),
      isEmpty,
    );
    expect(
      comparisonTables(
        _current(
          rows: [
            first,
            {...first, 'row_id': 'second'},
          ],
        ),
      ).single.values['sugars']!.value,
      12,
    );
  });

  test('historical disagreements never select a candidate value', () {
    final raw = _fixture(historical: true);
    final original = ProductReport.fromJson(raw);
    expect(
      comparisonTables(original),
      isEmpty,
    ); // conflict has no selected basis
    final protein = (raw['resolved_nutrients'] as List)
        .cast<JsonMap>()
        .singleWhere((row) => row['field'].endsWith('.protein'));
    protein['basis'] = {'kind': 'quantity', 'amount': 100, 'unit': 'g'};
    protein['preparation'] = 'as_sold';
    final table = comparisonTables(ProductReport.fromJson(raw)).single;
    expect(table.values['protein']!.conflict, isTrue);
    expect(table.values['protein']!.value, isNull);
    expect(table.values['protein']!.label, 'Conflicting values');
    expect(original.sourceLabels.first, contains('snapshot 2026-10-05'));
  });

  testWidgets(
    'saved and history pickers, swap and report links operate on real reports',
    (tester) async {
      final store = LocalStore(preferences: _MemoryPreferences());
      final a = _current();
      final b = _current(name: 'Oats B', sugar: 9);
      await store.save(a);
      await store.record(a);
      await store.record(b);
      final repository = _Repository();
      addTearDown(repository.close);
      final opened = <ProductReport>[];
      await tester.pumpWidget(_screen(store, repository, onOpen: opened.add));
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.text('Choose A'));
      expect(
        find.widgetWithText(ListTile, 'Oats A'),
        findsOneWidget,
      ); // deduplicated
      await _tapVisible(tester, find.widgetWithText(ListTile, 'Oats A'));
      await _pick(tester, 'B', 'Oats B');
      expect(find.text('A · 12 g'), findsOneWidget);
      expect(find.text('B · 9 g'), findsOneWidget);
      expect(find.text('A · 30 g'), findsNothing);
      expect(find.text('3 g more in A'), findsOneWidget);
      await _tapVisible(tester, find.text('Open report A'));
      expect(opened.single.id, a.id);
      await _tapVisible(tester, find.text('Swap'));
      expect(find.text('3 g more in B'), findsOneWidget);
      await _tapVisible(tester, find.text('Open report A'));
      expect(opened.last.id, b.id);
      expect(repository.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'barcode validates before lookup and failure preserves selection',
    (tester) async {
      final store = LocalStore(preferences: _MemoryPreferences());
      final repository = _Repository();
      addTearDown(repository.close);
      repository.loader = (_) async => throw const AppFailure(
        'not_found',
        'No product found for this barcode.',
      );
      await tester.pumpWidget(_screen(store, repository));
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.text('Choose A'));
      await tester.enterText(find.byType(TextFormField), '123');
      await _tapVisible(tester, find.text('Look up barcode'));
      expect(repository.calls, isEmpty);
      expect(
        find.text('Enter an 8, 12, 13 or 14 digit barcode.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextFormField), '0123456789012');
      await _tapVisible(tester, find.text('Look up barcode'));
      expect(repository.calls, ['0123456789012']);
      expect(find.text('No product found for this barcode.'), findsOneWidget);
      repository.loader = (_) async => _current(name: 'Barcode oats');
      await _tapVisible(tester, find.text('Look up barcode'));
      expect(find.text('Barcode oats'), findsOneWidget);
      expect(find.text('Change A'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        (await store.history()),
        isEmpty,
      ); // comparison does not record a scan
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('table selector changes the comparison context explicitly', (
    tester,
  ) async {
    final first =
        (((_fixture()['nutrition'] as JsonMap)['original_rows'] as List).single
            as JsonMap);
    final second = {
      ...first,
      'row_id': 'second-table-row',
      'table_id': 'second-table',
      'value': 30,
      'basis': {'kind': 'quantity', 'amount': 100, 'unit': 'g'},
    };
    final store = LocalStore(preferences: _MemoryPreferences());
    await store.save(_current(rows: [first, second]));
    await store.save(_current(name: 'Oats B', sugar: 9));
    final repository = _Repository();
    addTearDown(repository.close);
    await tester.pumpWidget(_screen(store, repository));
    await tester.pumpAndSettle();
    await _pick(tester, 'A', 'Oats A');
    await _pick(tester, 'B', 'Oats B');
    expect(find.text('3 g more in A'), findsOneWidget);
    await _tapVisible(tester, find.byType(DropdownButtonFormField<String>));
    await _tapVisible(tester, find.text('Per 100 g · as sold').last);
    expect(find.text('A · 30 g'), findsOneWidget);
    expect(find.text('3 g more in A'), findsNothing);
    expect(find.text('Different units or table basis'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'duplicate choice is rejected and closing pending lookup is safe',
    (tester) async {
      final store = LocalStore(preferences: _MemoryPreferences());
      await store.save(_current());
      final repository = _Repository();
      addTearDown(repository.close);
      await tester.pumpWidget(_screen(store, repository));
      await tester.pumpAndSettle();
      await _pick(tester, 'A', 'Oats A');
      await _pick(tester, 'B', 'Oats A');
      expect(
        find.text('Choose a different product for comparison.'),
        findsOneWidget,
      );
      expect(find.text('Choose B'), findsOneWidget);
      final pending = Completer<ProductReport>();
      repository.loader = (_) => pending.future;
      await _tapVisible(tester, find.text('Choose B'));
      await tester.enterText(find.byType(TextFormField), '0123456789012');
      await tester.tap(find.text('Look up barcode'));
      await tester.pump();
      expect(find.text('Looking up…'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      pending.complete(_current(name: 'Late result'));
      await tester.pumpAndSettle();
      expect(find.text('Late result'), findsNothing);
      expect(find.text('Choose B'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('light and dark comparison fit narrow screens and large text', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 680);
    tester.view.devicePixelRatio = 1;
    final store = LocalStore(preferences: _MemoryPreferences());
    await store.save(
      _current(name: 'A longer product name for narrow screens'),
    );
    await store.save(_current(name: 'A second longer product name', sugar: 9));
    final repository = _Repository();
    addTearDown(repository.close);
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        _screen(store, repository, brightness: brightness, textScale: 2),
      );
      await tester.pumpAndSettle();
      await _pick(tester, 'A', 'A longer product name for narrow screens');
      await _pick(tester, 'B', 'A second longer product name');
      await tester.ensureVisible(find.text('Original table values'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('A little context matters'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets(
    'paired cards stay side by side at normal phone and desktop widths',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      final store = LocalStore(preferences: _MemoryPreferences());
      final repository = _Repository();
      addTearDown(repository.close);
      for (final width in [320.0, 390.0, 768.0, 1440.0]) {
        tester.view.physicalSize = Size(width, 900);
        for (final brightness in Brightness.values) {
          await tester.pumpWidget(
            _screen(store, repository, brightness: brightness),
          );
          await tester.pumpAndSettle();
          final a = tester.getRect(
            find.byKey(const ValueKey('compare-product-A')),
          );
          final b = tester.getRect(
            find.byKey(const ValueKey('compare-product-B')),
          );
          expect(a.top, b.top);
          expect(a.right, lessThan(b.left));
          expect(a.width, closeTo(b.width, .1));
          expect(a.height, closeTo(b.height, .1));
          expect(find.text('Add a label'), findsNWidgets(2));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    },
  );

  testWidgets(
    'selected cards align report actions with different name lengths',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 900);
      final store = LocalStore(preferences: _MemoryPreferences());
      await store.save(_current());
      const longer = 'Whole grain oats with a longer printed product name';
      await store.save(_current(name: longer, sugar: 9));
      final repository = _Repository();
      addTearDown(repository.close);
      await tester.pumpWidget(_screen(store, repository, onOpen: (_) {}));
      await tester.pumpAndSettle();
      await _pick(tester, 'A', 'Oats A');
      await _pick(tester, 'B', longer);
      final a = tester.getRect(find.byKey(const ValueKey('compare-product-A')));
      final b = tester.getRect(find.byKey(const ValueKey('compare-product-B')));
      expect(a.height, closeTo(b.height, .1));
      expect(
        tester.getRect(find.text('Open report A')).bottom,
        closeTo(tester.getRect(find.text('Open report B')).bottom, .1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selected identity opens its report and bars keep missing values unknown',
    (tester) async {
      final store = LocalStore(preferences: _MemoryPreferences());
      final a = _current();
      await store.save(a);
      await store.save(_current(name: 'Oats B', sugar: 9));
      final repository = _Repository();
      addTearDown(repository.close);
      final opened = <ProductReport>[];
      await tester.pumpWidget(_screen(store, repository, onOpen: opened.add));
      await tester.pumpAndSettle();
      await _pick(tester, 'A', 'Oats A');
      await _pick(tester, 'B', 'Oats B');
      await _tapVisible(tester, find.byKey(const ValueKey('compare-report-A')));
      expect(opened.single.id, a.id);
      final sugar = find.byKey(const ValueKey('compare-nutrient-sugars'));
      final protein = find.byKey(const ValueKey('compare-nutrient-protein'));
      expect(
        find.descendant(
          of: sugar,
          matching: find.byType(LinearProgressIndicator),
        ),
        findsNWidgets(2),
      );
      expect(
        find.descendant(
          of: protein,
          matching: find.byType(LinearProgressIndicator),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: protein, matching: find.text('A · Unknown')),
        findsOneWidget,
      );
      expect(find.text('Matching label amounts'), findsOneWidget);
      expect(find.textContaining('/100'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unknown or mismatched values do not draw comparative bars', (
    tester,
  ) async {
    for (final right in [
      _current(name: 'Oats B', sugar: null),
      _current(
        name: 'Oats B',
        basis: {'kind': 'serving', 'amount': 50, 'unit': 'g'},
      ),
    ]) {
      final store = LocalStore(preferences: _MemoryPreferences());
      await store.save(_current());
      await store.save(right);
      final repository = _Repository();
      addTearDown(repository.close);
      await tester.pumpWidget(_screen(store, repository));
      await tester.pumpAndSettle();
      await _pick(tester, 'A', 'Oats A');
      await _pick(tester, 'B', 'Oats B');
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
