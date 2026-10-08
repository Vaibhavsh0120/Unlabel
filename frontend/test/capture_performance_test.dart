import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unlabel/core/capture/automatic_label_reader.dart';
import 'package:unlabel/core/network/unlabel_repository.dart';

import 'automatic_label_reader_test.dart' show barcodePhoto;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('synthetic known barcode uses warm public reads without photo upload', () async {
    final historical = File(
      '../contracts/examples/label-report-v1.historical.synthetic.json',
    ).readAsStringSync();
    var gets = 0, uploads = 0, consentCalls = 0;
    final repository = UnlabelRepository(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        if (request.method != 'GET') {
          uploads++;
          return http.Response('{}', 500);
        }
        gets++;
        if (request.url.path == '/v1/meta') {
          return http.Response(
            jsonEncode({
              'api_major': 1,
              'contract_schema': '1',
              'report_version': 'label-report-v1',
              'capabilities': {'label_reports': true},
            }),
            200,
          );
        }
        return http.Response(historical, 200);
      }),
    );
    final reader = AutomaticLabelReader(repository);
    addTearDown(repository.close);
    addTearDown(reader.dispose);
    final photo = await barcodePhoto();
    final samples = <double>[];
    for (var sample = 0; sample < 11; sample++) {
      final timer = Stopwatch()..start();
      final result = await reader.read(
        {2: photo},
        allowCloud: () async {
          consentCalls++;
          return true;
        },
      );
      timer.stop();
      samples.add(timer.elapsedMicroseconds / 1000);
      expect(result.barcode, '8901764051258');
      expect(result.report, isNotNull);
      expect(result.barcodePoints, isNotEmpty);
    }
    expect(gets, 2); // One capability GET and one historical report GET.
    expect(uploads, 0);
    expect(consentCalls, 0);
    const output = String.fromEnvironment('CAPTURE_BENCHMARK_OUTPUT');
    if (output.isNotEmpty) {
      final warm = samples.skip(1).toList()..sort();
      File(output).writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert({
          'schema_version': '1',
          'measured_at': DateTime.now().toUtc().toIso8601String(),
          'runtime': 'Flutter unit test, ${Platform.operatingSystem}, debug',
          'dart_version': Platform.version,
          'fixture': 'owned synthetic EAN-13, 600x180 PNG',
          'pipeline': 'actual image decode, ZXing, checksum and automatic reader; in-process HTTP responses and warm public report cache',
          'samples_ms': samples,
          'cold_ms': samples.first,
          'warm_count': warm.length,
          'warm_p50_ms': (warm[4] + warm[5]) / 2,
          'warm_p95_ms': warm.last,
          'metadata_and_report_gets': gets,
          'photo_posts': uploads,
          'consent_calls': consentCalls,
          'limitations': ['No physical camera or permission timing', 'No internet or production server latency', 'No real package, glare, focus or barcode accuracy benchmark', 'No 3-5 second end-to-end guarantee established'],
        })}\n',
      );
    }
  });
}
