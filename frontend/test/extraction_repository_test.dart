import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unlabel/core/network/scanner_auth.dart';
import 'package:unlabel/core/network/unlabel_repository.dart';

JsonMap _extraction() => jsonDecode(
  File('../contracts/examples/ai-extraction-v1.synthetic.json')
      .readAsStringSync(),
) as JsonMap;

final _photo = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGP4DwQACfsD/fteaysAAAAASUVORK5CYII=',
);

final _meta = {
  'api_major': 1,
  'contract_schema': '1',
  'report_version': 'label-report-v1',
  'capabilities': {'ai_extraction': true, 'ai_machine_observations': true},
};

Matcher _failure(String kind) =>
    isA<AppFailure>().having((value) => value.kind, 'kind', kind);

class _Auth implements ScannerAuth {
  _Auth(this.resolve);
  final Future<String?> Function() resolve;
  int calls = 0;
  @override
  Future<String?> token() {
    calls++;
    return resolve();
  }
}

class _StreamingClient extends http.BaseClient {
  _StreamingClient(this.respond);
  final Future<http.StreamedResponse> Function(http.BaseRequest) respond;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      respond(request);
}

http.StreamedResponse _metadataResponse() =>
    http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(_meta))), 200);

void main() {
  test(
    'photo upload uses scanner auth and consent, without provider selection',
    () async {
      final requests = <http.Request>[];
      final auth = _Auth(() async => 'synthetic-scanner-token');
      final repository = UnlabelRepository(
        baseUrl: 'https://example.test',
        auth: auth,
        client: MockClient((request) async {
          if (request.url.path == '/v1/meta') {
            return http.Response(jsonEncode(_meta), 200);
          }
          requests.add(request);
          return http.Response(
            jsonEncode({
              'status': 'extracted',
              'extraction': _extraction(),
              'storage': {
                'status': 'private_unverified',
                'content_sha256': 'a' * 64,
                'reason': null,
                'deduplicated': false,
              },
            }),
            200,
          );
        }),
      );
      addTearDown(repository.close);
      final label = await repository.extractPhotos({0: _photo, 1: _photo});
      expect(auth.calls, 1);
      expect(requests, hasLength(1));
      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/v1/ai/extract');
      expect(request.followRedirects, isFalse);
      expect(
        request.headers['Authorization'],
        'Bearer synthetic-scanner-token',
      );
      final body = jsonDecode(request.body) as JsonMap;
      expect(
        body.keys,
        unorderedEquals([
          'privacy_consent',
          'catalogue_contribution',
          'images',
        ]),
      );
      expect(body['catalogue_contribution'], 'machine-unverified-v1');
      expect(body['privacy_consent'], isTrue);
      expect((body['images'] as List).map((v) => v['slot']), ['front', 'back']);
      expect(base64Decode(body['images'][0]['data_base64']), _photo);
      expect(body['images'][0]['mime_type'], 'image/png');
      expect(label.storageStatus, 'private_unverified');
      expect(label.json.keys, isNot(contains('storage')));
      expect(label.nutritionTables.single['rows'][2]['value'], isNull);
    },
  );

  test(
    'missing, failed or timed-out scanner auth never uploads photos',
    () async {
      for (final resolve in <Future<String?> Function()>[
        () async => null,
        () async => throw StateError('synthetic-private-auth-details'),
        () => Completer<String?>().future,
      ]) {
        var uploads = 0;
        final repository = UnlabelRepository(
          baseUrl: 'https://example.test',
          auth: _Auth(resolve),
          authTimeout: const Duration(milliseconds: 10),
          client: MockClient((request) async {
            if (request.url.path == '/v1/meta') {
              return http.Response(jsonEncode(_meta), 200);
            }
            uploads++;
            return http.Response('{}', 500);
          }),
        );
        await expectLater(
          repository.extractPhotos({0: _photo}),
          throwsA(_failure('authentication')),
        );
        expect(uploads, 0);
        repository.close();
      }
    },
  );

  test(
    'an authentication failure never replays a photo POST or exposes its body',
    () async {
      var uploads = 0;
      final repository = UnlabelRepository(
        baseUrl: 'https://example.test',
        auth: _Auth(() async => 'synthetic-scanner-token'),
        client: MockClient((request) async {
          if (request.url.path == '/v1/meta') {
            return http.Response(jsonEncode(_meta), 200);
          }
          uploads++;
          return http.Response('synthetic-provider-key/private traceback', 401);
        }),
      );
      addTearDown(repository.close);
      await expectLater(
        repository.extractPhotos({0: _photo}),
        throwsA(
          allOf(
            _failure('authentication'),
            isA<AppFailure>().having(
              (value) => value.userMessage,
              'safe message',
              isNot(contains('synthetic-provider-key')),
            ),
          ),
        ),
      );
      expect(uploads, 1);
    },
  );

  test(
    'malformed machine evidence, geometry and storage stay unavailable',
    () async {
      for (final corrupt in <void Function(JsonMap)>[
        (v) => v['extraction']['evidence'] = 'confirmed_current_package',
        (v) => v['extraction']['regions'][0]['box']['left'] = -0.1,
        (v) => v['extraction']['provider_prompt'] = 'unexpected private field',
        (v) => v['storage'] = {'status': 'public_confirmed'},
        (v) => v['storage'] = {'status': 1},
      ]) {
        final value = <String, dynamic>{
          'status': 'extracted',
          'extraction': _extraction(),
        };
        corrupt(value);
        final repository = UnlabelRepository(
          baseUrl: 'https://example.test',
          auth: _Auth(() async => 'synthetic-scanner-token'),
          client: MockClient(
            (request) async => http.Response(
              jsonEncode(request.url.path == '/v1/meta' ? _meta : value),
              200,
            ),
          ),
        );
        await expectLater(
          repository.extractPhotos({0: _photo}),
          throwsA(_failure('invalid_response')),
        );
        repository.close();
      }
    },
  );

  test(
    'invalid photo batches stop before metadata or authentication',
    () async {
      var requests = 0;
      final auth = _Auth(() async => 'synthetic-scanner-token');
      final repository = UnlabelRepository(
        baseUrl: 'https://example.test',
        auth: auth,
        client: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );
      addTearDown(repository.close);
      for (final batch in <Map<int, Uint8List>>[
        {},
        {3: _photo},
        {0: Uint8List(0)},
        {0: Uint8List(900001)},
      ]) {
        await expectLater(
          repository.extractPhotos(batch),
          throwsA(_failure('invalid_photo')),
        );
      }
      expect(requests, 0);
      expect(auth.calls, 0);
    },
  );

  test(
    'cancellation during scanner authentication prevents a late upload',
    () async {
      final abort = Completer<void>();
      final authStarted = Completer<void>();
      final token = Completer<String?>();
      var uploads = 0;
      final repository = UnlabelRepository(
        baseUrl: 'https://example.test',
        auth: _Auth(() {
          authStarted.complete();
          return token.future;
        }),
        client: MockClient((request) async {
          if (request.url.path == '/v1/meta') {
            return http.Response(jsonEncode(_meta), 200);
          }
          uploads++;
          return http.Response('{}', 500);
        }),
      );
      addTearDown(repository.close);
      final reading = repository.extractPhotos({
        0: _photo,
      }, abortTrigger: abort.future);
      final result = expectLater(reading, throwsA(_failure('cancelled')));
      await authStarted.future;
      abort.complete();
      await result;
      token.complete('synthetic-late-token');
      await Future<void>.delayed(Duration.zero);
      expect(uploads, 0);
    },
  );

  test(
    'cancellation reaches the upload request and never repeats the POST',
    () async {
      final abort = Completer<void>();
      final started = Completer<void>();
      var uploads = 0, aborted = false;
      final repository = UnlabelRepository(
        baseUrl: 'https://example.test',
        auth: _Auth(() async => 'synthetic-scanner-token'),
        client: _StreamingClient((request) {
          if (request.url.path == '/v1/meta') {
            return Future.value(_metadataResponse());
          }
          uploads++;
          final response = Completer<http.StreamedResponse>();
          (request as http.AbortableRequest).abortTrigger!.then((_) {
            aborted = true;
            response.completeError(http.RequestAbortedException(request.url));
          });
          started.complete();
          return response.future;
        }),
      );
      addTearDown(repository.close);
      final result = expectLater(
        repository.extractPhotos({0: _photo}, abortTrigger: abort.future),
        throwsA(_failure('cancelled')),
      );
      await started.future;
      abort.complete();
      await result;
      await Future<void>.delayed(Duration.zero);
      expect(aborted, isTrue);
      expect(uploads, 1);
    },
  );

  test(
    'cancellation while response bytes arrive does not parse partial facts',
    () async {
      final abort = Completer<void>();
      final started = Completer<void>();
      final stream = StreamController<List<int>>();
      var uploads = 0;
      final repository = UnlabelRepository(
        baseUrl: 'https://example.test',
        auth: _Auth(() async => 'synthetic-scanner-token'),
        client: _StreamingClient((request) async {
          if (request.url.path == '/v1/meta') return _metadataResponse();
          uploads++;
          (request as http.AbortableRequest).abortTrigger!.then((_) {
            stream.addError(http.RequestAbortedException(request.url));
            unawaited(stream.close());
          });
          started.complete();
          stream.add(utf8.encode('{"status":"extracted","extraction":'));
          return http.StreamedResponse(stream.stream, 200);
        }),
      );
      addTearDown(repository.close);
      final result = expectLater(
        repository.extractPhotos({0: _photo}, abortTrigger: abort.future),
        throwsA(_failure('cancelled')),
      );
      await started.future;
      await Future<void>.delayed(Duration.zero);
      abort.complete();
      await result;
      await Future<void>.delayed(Duration.zero);
      expect(uploads, 1);
    },
  );
}
