import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unlabel/app/unlabel_theme.dart';
import 'package:unlabel/core/network/unlabel_repository.dart';
import 'package:unlabel/core/storage/local_store.dart';
import 'package:unlabel/features/scanner/presentation/compare_page.dart';
import 'package:unlabel/features/scanner/presentation/report_page.dart';

JsonMap _fixture(String name) =>
    jsonDecode(File('../contracts/examples/$name').readAsStringSync())
        as JsonMap;

class _Preferences implements PreferencesAdapter {
  final data = <String, String>{};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async => data[key] = value;
  @override
  Future<void> remove(String key) async => data.remove(key);
}

ProductReport _report(String name, {bool session = true}) {
  final raw = _fixture('label-report-v1.current.synthetic.json');
  raw['identity']['name'] = name;
  return ProductReport.fromJson(
    raw,
    confirmedComparisonObservation: session
        ? _fixture('comparison-v1.request.synthetic.json')['a']['observation']
              as JsonMap
        : null,
  );
}

Widget _app(
  LocalStore store,
  UnlabelRepository repo,
  List<ProductReport> reports, {
  Brightness brightness = Brightness.light,
  double scale = 1,
}) => MaterialApp(
  theme: UnlabelTheme.forBrightness(brightness),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    body: ComparePage(store: store, repository: repo, sessionReports: reports),
  ),
);
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _pick(WidgetTester tester, String side, String name) async {
  await _tap(tester, find.text('Choose $side'));
  await _tap(tester, find.widgetWithText(ListTile, name));
}

http.Response _response(JsonMap body, {double sugarDifference = 0}) {
  final raw = _fixture('comparison-v1.response.synthetic.json');
  for (final key in [
    'client_request_id',
    'comparison_session_id',
    'input_revision',
  ]) {
    raw[key] = body[key];
  }
  if (sugarDifference != 0) {
    raw['nutrients'][5]['b']['value'] = 30 + sugarDifference;
    raw['nutrients'][5]['difference'] = sugarDifference;
    raw['nutrients'][5]['lower'] = sugarDifference > 0 ? 'a' : 'b';
  }
  return http.Response(jsonEncode(raw), 200);
}

void main() {
  testWidgets(
    'sourced cards, selectors and evidence fit320px with2x light/dark text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 680);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final store = LocalStore(preferences: _Preferences());
      final reports = [_report('Session A'), _report('Session B')];
      for (final report in reports) {
        await store.record(report);
      }
      final repo = UnlabelRepository(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          if (request.url.path == '/v1/meta') {
            return http.Response(
              jsonEncode({
                'api_major': 1,
                'contract_schema': '1',
                'report_version': 'label-report-v1',
                'comparison_version': comparisonVersion,
                'capabilities': {'comparison': true},
              }),
              200,
            );
          }
          return _response(jsonDecode(request.body) as JsonMap);
        }),
      );
      addTearDown(repo.close);
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          _app(store, repo, reports, brightness: brightness, scale: 2),
        );
        await _pick(tester, 'A', 'Session A');
        await _pick(tester, 'B', 'Session B');
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.text('Original rows & source references'),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets(
    'server comparison shows common basis and rejects a late swapped result',
    (tester) async {
      final pending = <Completer<http.Response>>[];
      final bodies = <JsonMap>[];
      final repo = UnlabelRepository(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          if (request.url.path == '/v1/meta') {
            return http.Response(
              jsonEncode({
                'api_major': 1,
                'contract_schema': '1',
                'report_version': 'label-report-v1',
                'comparison_version': comparisonVersion,
                'capabilities': {'comparison': true},
              }),
              200,
            );
          }
          bodies.add(jsonDecode(request.body) as JsonMap);
          final result = Completer<http.Response>();
          pending.add(result);
          return result.future;
        }),
      );
      addTearDown(repo.close);
      final store = LocalStore(preferences: _Preferences());
      await store.record(_report('Session A'));
      await store.record(_report('Session B'));
      await tester.pumpWidget(
        _app(store, repo, [_report('Session A'), _report('Session B')]),
      );
      await _pick(tester, 'A', 'Session A');
      await _pick(tester, 'B', 'Session B');
      expect(pending, hasLength(1));
      expect(find.text('Comparing sourced amounts…'), findsOneWidget);
      await _tap(tester, find.text('Swap'));
      expect(pending, hasLength(2));
      pending[1].complete(_response(bodies[1], sugarDifference: 5));
      await tester.pumpAndSettle();
      expect(find.text('Per 100 g · as sold'), findsWidgets);
      expect(find.text('5 g more in B'), findsOneWidget);
      pending[0].complete(_response(bodies[0], sugarDifference: 99));
      await tester.pumpAndSettle();
      expect(find.text('99 g more in B'), findsNothing);
      expect(find.text('5 g more in B'), findsOneWidget);
      await _tap(tester, find.text('Original rows & source references'));
      expect(find.textContaining('not independently verified'), findsWidgets);
      expect(find.textContaining('12 g'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'restored current reports explain lost confirmation and namespace changes clear selections',
    (tester) async {
      final store = LocalStore(preferences: _Preferences());
      await store.record(_report('Restored A', session: false));
      await store.record(_report('Restored B', session: false));
      final repo = UnlabelRepository(baseUrl: 'https://example.test');
      addTearDown(repo.close);
      await tester.pumpWidget(_app(store, repo, []));
      await _pick(tester, 'A', 'Restored A');
      await _pick(tester, 'B', 'Restored B');
      expect(find.textContaining('Review this label again'), findsWidgets);
      await tester.pumpWidget(
        _app(LocalStore(preferences: _Preferences()), repo, []),
      );
      await tester.pumpAndSettle();
      expect(find.text('Restored A'), findsNothing);
      expect(find.text('Choose A'), findsOneWidget);
    },
  );

  testWidgets('cleared library cannot revive a retained session confirmation', (
    tester,
  ) async {
    final store = LocalStore(preferences: _Preferences());
    final report = _report('Cleared session');
    await store.record(report);
    await store.clearHistory();
    final repo = UnlabelRepository(baseUrl: 'https://example.test');
    addTearDown(repo.close);
    await tester.pumpWidget(_app(store, repo, [report]));
    await _tap(tester, find.text('Choose A'));
    expect(find.widgetWithText(ListTile, 'Cleared session'), findsNothing);
    expect(
      find.text('Your library is empty. Look up a barcode above.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'ingredient detail keeps bilingual function and original evidence URL and review date',
    (tester) async {
      final report = _report('Synthetic');
      await tester.pumpWidget(
        MaterialApp(
          theme: UnlabelTheme.forBrightness(Brightness.light),
          home: IngredientPage(report: report),
        ),
      );
      await tester.pumpAndSettle();
      final insight = report.ingredientInsights.first;
      await _tap(tester, find.text(insight.name).first);
      await _tap(tester, find.text('Read ingredient evidence'));
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(insight.function), findsWidgets);
      expect(find.text(insight.functionHi!), findsWidgets);
      expect(find.text(insight.sourceIds.single), findsOneWidget);
      final source = (report.raw['glossary_sources'] as List).first as JsonMap;
      expect(find.text(source['url'] as String), findsOneWidget);
      expect(find.text('Reviewed ${source['reviewed_on']}'), findsOneWidget);
      expect(find.textContaining('does not establish'), findsWidgets);
    },
  );
}
