import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unlabel/app/unlabel_theme.dart';
import 'package:unlabel/core/network/scanner_auth.dart';
import 'package:unlabel/core/network/unlabel_repository.dart';
import 'package:unlabel/features/scanner/presentation/product_info_page.dart';

const code = '012345678905';
JsonMap liveJson(DateTime now, {Duration ttl = const Duration(hours: 24)}) => {
  'status': 'found',
  'requested_barcode': code,
  'product': {
    'barcode': code,
    'name': 'Synthetic live product',
    'brand': 'Synthetic',
    'evidence': 'external_provider_unverified',
    'attribution': 'Data by NutriGraphAPI',
    'attribution_url': 'https://nutrigraphapi.com',
    'retrieved_at': now.toUtc().toIso8601String(),
    'expires_at': now.toUtc().add(ttl).toIso8601String(),
    'sources': <String>[],
    'fields': [
      {
        'section': 'ingredients',
        'label': 'Provider ingredient list',
        'value': 'SYNTHETIC LIVE ONLY',
        'sources': <String>[],
      },
    ],
  },
};

class _Auth implements ScannerAuth {
  int calls = 0;
  @override
  Future<String?> token() async {
    calls++;
    return 'synthetic-token';
  }
}

class _Repository extends UnlabelRepository {
  _Repository() : super(baseUrl: 'https://example.test');
  @override
  Future<LiveProductLookup> liveProduct(String barcode) async =>
      LiveProductLookup.fromJson(
        liveJson(DateTime.now(), ttl: const Duration(seconds: 1)),
        code,
        DateTime.now(),
      );
  @override
  Future<MachineProductLookup> machineProduct(String barcode) async =>
      const MachineProductLookup([], []);
}

void main() {
  test('disabled vendor makes no lookup or authentication request', () async {
    final auth = _Auth();
    final paths = <String>[];
    final repository = UnlabelRepository(
      baseUrl: 'https://example.test',
      auth: auth,
      client: MockClient((request) async {
        paths.add(request.url.path);
        return http.Response(
          jsonEncode({
            'api_major': 1,
            'contract_schema': '1',
            'report_version': 'label-report-v1',
            'capabilities': {'live_nutrigraph': false},
          }),
          200,
        );
      }),
    );
    addTearDown(repository.close);
    expect((await repository.liveProduct(code)).status, 'disabled');
    expect(paths, ['/v1/meta']);
    expect(auth.calls, 0);
  });
  test(
    'live request uses bearer auth and has no client result cache',
    () async {
      final auth = _Auth();
      var calls = 0;
      final now = DateTime.now().toUtc();
      final repository = UnlabelRepository(
        baseUrl: 'https://example.test',
        auth: auth,
        client: MockClient((request) async {
          if (request.url.path == '/v1/meta') {
            return http.Response(
              jsonEncode({
                'api_major': 1,
                'contract_schema': '1',
                'report_version': 'label-report-v1',
                'capabilities': {'live_nutrigraph': true},
              }),
              200,
            );
          }
          calls++;
          expect(request.headers['Authorization'], 'Bearer synthetic-token');
          expect(request.followRedirects, isFalse);
          expect(request.method, 'GET');
          return http.Response(jsonEncode(liveJson(now)), 200);
        }),
      );
      addTearDown(repository.close);
      await repository.liveProduct(code);
      await repository.liveProduct(code);
      expect(calls, 2);
    },
  );
  test('mismatched identity, retention extension and promoted evidence are rejected', () {
    final now = DateTime.now().toUtc();
    for (final mutate in <void Function(JsonMap)>[
      (v) => v['product']['barcode'] = '8901764051258',
      (v) => v['product']['evidence'] = 'human_confirmed',
      (v) => v['product']['expires_at'] = now
          .add(const Duration(hours: 25))
          .toIso8601String(),
    ]) {
      final value = liveJson(now);
      mutate(value);
      expect(
        () => LiveProductLookup.fromJson(value, code, now),
        throwsA(isA<AppFailure>()),
      );
    }
    expect(
      LiveProductLookup.fromJson(
        liveJson(now.subtract(const Duration(days: 2))),
        code,
        now,
      ).product,
      isNull,
    );
  });
  testWidgets(
    'an open product page drops expired live facts and retains the base page',
    (tester) async {
      final repository = _Repository();
      addTearDown(repository.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: UnlabelTheme.forBrightness(Brightness.light),
          home: ProductInfoPage.barcode(barcode: code, repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('SYNTHETIC LIVE ONLY'), findsOneWidget);
      expect(find.text('Data by NutriGraphAPI'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('SYNTHETIC LIVE ONLY'), findsNothing);
      expect(find.text('Scanned product'), findsOneWidget);
      expect(find.text('Live lookup unavailable'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
