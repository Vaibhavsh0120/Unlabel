import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unlabel/core/accounts/account_auth.dart';
import 'package:unlabel/core/accounts/profile_media.dart';
import 'package:unlabel/core/accounts/selfhost_profile_media.dart';
import 'package:unlabel/core/models/app_failure.dart';

class _Auth extends UnavailableAccountAuth {
  String uid = 'owner';
  @override
  AccountIdentity get identity => AccountIdentity(uid: uid);
  @override
  Future<String> token(String expectedUid) async {
    if (expectedUid != uid) {
      throw const AppFailure('account_changed', 'Changed');
    }
    return 'token-$uid';
  }
}

Map<String, Object?> snapshot({
  int revision = 0,
  String preference = 'automatic',
  String gender = 'unset',
}) => {
  'schema_version': '1',
  'revision': revision,
  'gender': gender,
  'display_name': 'Private profile',
  'avatar_preference': preference,
  'avatar_png_base64': null,
  'avatar_source': 'default',
  'updated_at': null,
};

void main() {
  test('profile uses verified owner, preserves explicit avatar choice and checks revision', () async {
    final auth = _Auth();
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      expect(request.headers['authorization'], 'Bearer token-owner');
      expect(request.url.path, '/v1/account/profile');
      expect(request.url.hasQuery, isFalse);
      if (request.method == 'GET') {
        return http.Response(jsonEncode(snapshot()), 200);
      }
      final body = jsonDecode(request.body);
      expect(body['expected_revision'], requests.length - 2);
      expect(body['display_name'], 'Private profile');
      expect(body.containsKey('owner'), isFalse);
      return http.Response(
        jsonEncode(
          snapshot(
            revision: requests.length - 1,
            preference: body['avatar_preference'] as String,
            gender: body['gender'] as String,
          ),
        ),
        200,
      );
    });
    addTearDown(client.close);
    addTearDown(auth.dispose);
    final repository = SelfhostProfileMediaRepository(
      origin: Uri.parse('https://api.example'),
      auth: auth,
      client: client,
    );
    expect(
      (await repository.watch('owner').first).source,
      ProfileAvatarSource.automatic,
    );
    await repository.write(
      'owner',
      ProfileMedia(source: ProfileAvatarSource.defaultAvatar),
    );
    await repository.write(
      'owner',
      ProfileMedia(
        gender: ProfileGender.female,
        source: ProfileAvatarSource.google,
      ),
    );
    expect(requests.length, 3);
  });

  test(
    'a late previous-owner response never opens or writes a new owner profile',
    () async {
      final auth = _Auth();
      final response = Completer<http.Response>();
      final started = Completer<void>();
      var requests = 0;
      final client = MockClient((_) {
        requests++;
        started.complete();
        return response.future;
      });
      addTearDown(client.close);
      addTearDown(auth.dispose);
      final repository = SelfhostProfileMediaRepository(
        origin: Uri.parse('https://api.example'),
        auth: auth,
        client: client,
      );
      final read = repository.watch('owner').first;
      await started.future;
      auth.uid = 'new-owner';
      response.complete(http.Response(jsonEncode(snapshot()), 200));
      await expectLater(read, throwsA(isA<AppFailure>()));
      await expectLater(
        repository.write('new-owner', ProfileMedia()),
        throwsA(isA<AppFailure>()),
      );
      expect(requests, 1);
    },
  );

  test(
    'a conflicting profile revision cannot silently overwrite another device',
    () async {
      final auth = _Auth();
      final client = MockClient(
        (request) async => request.method == 'GET'
            ? http.Response(jsonEncode(snapshot(revision: 4)), 200)
            : http.Response('{}', 409),
      );
      addTearDown(client.close);
      addTearDown(auth.dispose);
      final repository = SelfhostProfileMediaRepository(
        origin: Uri.parse('https://api.example'),
        auth: auth,
        client: client,
      );
      await repository.watch('owner').first;
      await expectLater(
        repository.write('owner', ProfileMedia()),
        throwsA(
          isA<AppFailure>().having((e) => e.kind, 'kind', 'profile_conflict'),
        ),
      );
    },
  );
}
