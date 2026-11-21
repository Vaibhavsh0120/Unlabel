import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unlabel/core/accounts/selfhost_account_auth.dart';
import 'package:unlabel/core/accounts/selfhost_account_session_storage.dart';
import 'package:unlabel/core/accounts/selfhost_auth_client.dart';
import 'package:unlabel/core/models/app_failure.dart';

const guestId = '18e8498c-edfd-4837-8e74-44223d3aaf15';
const nextGuestId = '5d3f96c2-d7e6-4a71-943a-f27be5b299d0';
const userId = '51999091-193d-4daf-8e3f-3de5c9fd3894';
const email = 'scanner@example.test';
const password = ' test-only password ';

Map<String, Object?> user({String id = userId, bool anonymous = false}) => {
  'id': id,
  'is_anonymous': anonymous,
  if (!anonymous) 'email': email,
  if (!anonymous) 'user_metadata': {'display_name': 'Test Scanner'},
  if (!anonymous)
    'app_metadata': {
      'providers': ['email', 'google'],
    },
};

Map<String, Object?> token(
  String access, {
  String id = userId,
  bool anonymous = false,
}) => {
  'access_token': access,
  'refresh_token': 'refresh-$access',
  'token_type': 'bearer',
  'expires_in': 900,
  'user': user(id: id, anonymous: anonymous),
};

http.Response reply(Object? json, [int status = 200]) => http.Response(
  jsonEncode(json),
  status,
  headers: {'Content-Type': 'application/json'},
);

void main() {
  final origin = Uri.parse('https://unlabel.example.test');
  late DateTime clock;

  setUp(() => clock = DateTime.utc(2026, 11, 16));

  SelfhostAuthClient api(
    Future<http.Response> Function(http.Request) respond, {
    Duration timeout = const Duration(seconds: 10),
  }) {
    final httpClient = MockClient(respond);
    addTearDown(httpClient.close);
    return SelfhostAuthClient(
      origin: origin,
      client: httpClient,
      now: () => clock,
      timeout: timeout,
    );
  }

  SelfhostAccountAuth account(
    SelfhostAuthClient client, {
    SelfhostAccountSessionStorage? sessionStorage,
  }) {
    final auth = SelfhostAccountAuth(
      client: client,
      sessionStorage: sessionStorage,
      now: () => clock,
    );
    addTearDown(auth.dispose);
    return auth;
  }

  test(
    'restores and rotates the saved account session, then clears on sign-out',
    () async {
      final storage = MemorySelfhostAccountSessionStorage(
        const StoredSelfhostAccountSession(
          userId: userId,
          refreshToken: 'refresh-saved',
        ),
      );
      final requests = <http.Request>[];
      final auth = account(
        api((request) async {
          requests.add(request);
          if (request.url.queryParameters['grant_type'] == 'refresh_token') {
            expect(jsonDecode(request.body), {
              'refresh_token': 'refresh-saved',
            });
            return reply(token('restored', id: userId));
          }
          expect(request.url.path, '/auth/v1/logout');
          expect(request.headers['authorization'], 'Bearer restored');
          return http.Response('', 204);
        }),
        sessionStorage: storage,
      );

      await auth.start();
      expect(auth.identity?.uid, userId);
      expect(storage.session?.userId, userId);
      expect(storage.session?.refreshToken, 'refresh-restored');
      await auth.signOut();
      expect(auth.identity, isNull);
      expect(storage.session, isNull);
      expect(requests.map((request) => request.url.path), [
        '/auth/v1/token',
        '/auth/v1/logout',
      ]);
    },
  );

  test(
    'expired persisted account session is removed without replacing its uid',
    () async {
      final storage = MemorySelfhostAccountSessionStorage(
        const StoredSelfhostAccountSession(
          userId: userId,
          refreshToken: 'refresh-expired',
        ),
      );
      final auth = account(
        api((request) async {
          expect(request.url.queryParameters, {'grant_type': 'refresh_token'});
          return reply({'error_code': 'refresh_token_not_found'}, 400);
        }),
        sessionStorage: storage,
      );

      await auth.start();
      expect(auth.identity, isNull);
      expect(storage.session, isNull);
    },
  );

  test('guard the credential destination and permit explicit loopback', () {
    final client = MockClient((_) async => throw StateError('no request'));
    addTearDown(client.close);
    for (final value in [
      'http://api.example.test',
      'https://user@api.example.test',
      'https://api.example.test/path',
      'https://api.example.test?token=invalid',
      'https://api.example.test/#callback',
    ]) {
      expect(
        () => SelfhostAuthClient(
          origin: Uri.parse(value),
          client: client,
          allowInsecureLoopback: true,
        ),
        throwsArgumentError,
      );
    }

    expect(
      SelfhostAuthClient(
        origin: Uri.parse('http://127.0.0.1:8000'),
        client: client,
        allowInsecureLoopback: true,
      ),
      isA<SelfhostAuthClient>(),
    );
  });

  test(
    'email signup respects confirmation, then password login maps owner',
    () async {
      final requests = <http.Request>[];
      final client = api((request) async {
        requests.add(request);
        return request.url.path.endsWith('/signup')
            ? reply(user())
            : reply(token('signed-in'));
      });
      final redirect = Uri.parse('https://app.example.test/#/account-signin');
      expect(
        await client.signUpEmail(
          email: ' $email ',
          password: password,
          displayName: ' Test Scanner ',
          redirectTo: redirect,
        ),
        isNull,
      );
      final session = await client.signInPassword(
        email: email,
        password: password,
      );
      expect(session.user.id, userId);
      expect(session.user.displayName, 'Test Scanner');
      expect(session.user.providers, {'password', 'google.com'});
      expect(session.expiresAt, clock.add(const Duration(minutes: 15)));
      expect(requests[0].url.path, '/auth/v1/signup');
      expect(requests[0].url.queryParameters, {'redirect_to': '$redirect'});
      expect(jsonDecode(requests[0].body), {
        'email': email,
        'password': password,
        'data': {'display_name': 'Test Scanner'},
      });
      expect(requests[1].url.path, '/auth/v1/token');
      expect(requests[1].url.queryParameters, {'grant_type': 'password'});
      expect(jsonDecode(requests[1].body), {
        'email': email,
        'password': password,
      });
      expect(requests.every((request) => !request.followRedirects), isTrue);
    },
  );

  test('Google exchange only sends the ID token, provider and nonce', () async {
    final client = api((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/auth/v1/token');
      expect(request.url.queryParameters, {'grant_type': 'id_token'});
      expect(request.headers['authorization'], isNull);
      expect(jsonDecode(request.body), {
        'provider': 'google',
        'id_token': 'google-test-id-token',
        'nonce': 'test-nonce',
      });
      return reply(token('google-session'));
    });
    final session = await client.signInGoogle(
      idToken: 'google-test-id-token',
      nonce: 'test-nonce',
    );
    expect(session.user.id, userId);
  });

  test('password recovery and logout keep bearer tokens out of URLs', () async {
    final responses = <String>[];
    final client = api((request) async {
      responses.add('${request.method} ${request.url.path}');
      return switch (request.url.path) {
        '/auth/v1/recover' => reply({}),
        '/auth/v1/token' => reply(token('authenticated')),
        '/auth/v1/logout' => (() {
          expect(request.headers['authorization'], 'Bearer authenticated');
          expect(request.url.queryParameters, {'scope': 'local'});
          return http.Response('', 204);
        })(),
        _ => throw StateError('Unexpected auth request'),
      };
    });
    await client.requestRecovery(email: email);
    final session = await client.signInPassword(
      email: email,
      password: password,
    );
    await client.signOut(session);
    expect(responses, [
      'POST /auth/v1/recover',
      'POST /auth/v1/token',
      'POST /auth/v1/logout',
    ]);
  });

  test('reject hostile bodies without surfacing provider details', () async {
    final malformed = reply({'user': 'secret-provider-value'});
    final large = http.Response('x' * (256 * 1024 + 1), 200);
    final moved = http.Response(
      '',
      302,
      headers: {'Location': 'https://other.test'},
    );
    final expired = reply({
      'error_code': 'otp_expired',
      'msg': 'secret-provider-value',
    }, 400);
    final responses = [malformed, large, moved, expired];
    final client = api((_) async => responses.removeAt(0));
    for (final kind in [
      'invalid_auth_response',
      'invalid_auth_response',
      'invalid_auth_response',
      'recovery_expired',
    ]) {
      await expectLater(
        client.signInPassword(email: email, password: password),
        throwsA(
          isA<SelfhostAuthFailure>()
              .having((error) => error.kind, 'kind', kind)
              .having(
                (error) => '$error',
                'display',
                isNot(contains('secret-provider-value')),
              ),
        ),
      );
    }
  });

  test(
    'refresh rejects a different user even after a successful grant',
    () async {
      final client = api((request) async {
        if (request.url.path.endsWith('/signup')) {
          return reply(token('original-guest', id: guestId, anonymous: true));
        }
        expect(jsonDecode(request.body), {
          'refresh_token': 'refresh-original-guest',
        });
        return reply(token('wrong-owner', id: nextGuestId, anonymous: true));
      });
      final original = await client.signInGuest();
      await expectLater(
        client.refresh(original),
        throwsA(
          isA<SelfhostAuthFailure>().having(
            (e) => e.kind,
            'kind',
            'invalid_auth_response',
          ),
        ),
      );
    },
  );

  test(
    'expired guest refresh is replaced once across concurrent scans',
    () async {
      var signups = 0;
      var refreshes = 0;
      final auth = account(
        api((request) async {
          if (request.url.path.endsWith('/signup')) {
            expect(jsonDecode(request.body), isEmpty);
            signups++;
            return reply(
              token(
                'guest-$signups',
                id: signups == 1 ? guestId : nextGuestId,
                anonymous: true,
              ),
            );
          }
          refreshes++;
          expect(request.url.queryParameters, {'grant_type': 'refresh_token'});
          return reply({'error_code': 'refresh_token_not_found'}, 400);
        }),
      );
      await auth.start();
      expect(signups, 0);
      expect(await auth.scannerAuth.token(), 'guest-1');
      clock = clock.add(const Duration(days: 8));
      expect(
        await Future.wait([auth.scannerAuth.token(), auth.scannerAuth.token()]),
        ['guest-2', 'guest-2'],
      );
      expect(auth.identity, isNull);
      expect(signups, 2);
      expect(refreshes, 1);
    },
  );

  test('failed network refresh does not create another guest', () async {
    var signups = 0;
    var refreshes = 0;
    final auth = account(
      api((request) async {
        if (request.url.path.endsWith('/signup')) {
          signups++;
          return reply(token('guest', id: guestId, anonymous: true));
        }
        refreshes++;
        // A failure body may be untrustworthy if its status is transient.
        return reply({'error_code': 'refresh_token_not_found'}, 503);
      }),
    );
    expect(await auth.scannerAuth.token(), 'guest');
    clock = clock.add(const Duration(minutes: 15));
    expect(await auth.scannerAuth.token(), isNull);
    expect(await auth.scannerAuth.token(), isNull);
    expect(signups, 1);
    expect(refreshes, 2);
  });

  test(
    'late guest request cannot expose a token after account sign-in',
    () async {
      final pendingSignup = Completer<http.Response>();
      final signupStarted = Completer<void>();
      final auth = account(
        api((request) async {
          if (request.url.path.endsWith('/signup')) {
            signupStarted.complete();
            return pendingSignup.future;
          }
          if (request.url.path.endsWith('/logout')) {
            return http.Response('', 204);
          }
          return reply(token('account-session'));
        }),
      );
      final request = auth.scannerAuth.token();
      await signupStarted.future;
      await auth.signIn(email, password);
      pendingSignup.complete(
        reply(token('guest', id: guestId, anonymous: true)),
      );
      expect(await request, isNull);
      expect(await auth.scannerAuth.token(), 'account-session');
      expect(await auth.token(userId), 'account-session');
      await expectLater(auth.token(guestId), throwsA(isA<AppFailure>()));
      await auth.signOut();
      expect(auth.identity, isNull);
    },
  );

  test('private sync and scanner share a rotated signed-in token', () async {
    var refreshes = 0;
    final auth = account(
      api((request) async {
        if (request.url.queryParameters['grant_type'] == 'refresh_token') {
          refreshes++;
          expect(jsonDecode(request.body), {
            'refresh_token': 'refresh-initial',
          });
          return reply(token('rotated'));
        }
        return reply(token('initial'));
      }),
    );
    await auth.signIn(email, password);
    clock = clock.add(const Duration(minutes: 15));
    expect(
      await Future.wait([
        auth.scannerAuth.token(),
        auth.token(userId),
        auth.token(userId),
      ]),
      ['rotated', 'rotated', 'rotated'],
    );
    expect(refreshes, 1);
    expect(auth.identity?.uid, userId);
  });

  test('confirmation-only signup cannot activate a password account', () async {
    final auth = account(api((_) async => reply(user())));
    await expectLater(
      auth.create(email, password),
      throwsA(
        isA<AppFailure>().having(
          (error) => error.kind,
          'kind',
          'email_confirmation_pending',
        ),
      ),
    );
    expect(auth.identity, isNull);
  });

  test(
    'browser Google exchanges a bound authorization code through the API',
    () async {
      final auth = SelfhostAccountAuth(
        now: () => clock,
        client: api((request) async {
          expect(request.url.queryParameters, {'grant_type': 'pkce'});
          expect(jsonDecode(request.body), {
            'auth_code': 'one-time',
            'code_verifier': 'verifier',
          });
          return reply(token('web-account'));
        }),
        googleOAuth: (accessToken) async {
          expect(accessToken, isNull);
          return {'auth_code': 'one-time', 'code_verifier': 'verifier'};
        },
      );
      addTearDown(auth.dispose);
      await auth.signInGoogle();
      expect(auth.identity?.uid, userId);
      expect(await auth.scannerAuth.token(), 'web-account');
    },
  );

  test(
    'Google reauthentication mismatch cannot delete or select another library',
    () async {
      var privateDeleted = false, localDeleted = false, revokedOther = false;
      final auth = SelfhostAccountAuth(
        now: () => clock,
        client: api((request) async {
          if (request.url.path.endsWith('/logout')) {
            expect(
              request.headers['authorization'],
              'Bearer other-google-account',
            );
            revokedOther = true;
            return http.Response('', 204);
          }
          if (request.url.queryParameters['grant_type'] == 'id_token') {
            return reply(token('other-google-account', id: nextGuestId));
          }
          return reply(token('owner'));
        }),
        googleIdToken: () async => 'synthetic-google-id-token',
      );
      addTearDown(auth.dispose);
      await auth.signIn(email, password);
      await expectLater(
        auth.deleteAccount(
          deletePrivateData: (_, _) async {
            privateDeleted = true;
          },
          deleteLocalData: () async {
            localDeleted = true;
          },
        ),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.kind,
            'kind',
            'reauthentication_mismatch',
          ),
        ),
      );
      expect(privateDeleted || localDeleted, isFalse);
      expect(revokedOther, isTrue);
      expect(auth.identity?.uid, userId);
      expect(await auth.token(userId), 'owner');
    },
  );

  test('account deletion requires fresh password and preserves local data if the API fails', () async {
    var privateCalls = 0, localCalls = 0;
    var fail = true;
    final auth = account(
      api((request) async {
        expect(request.url.queryParameters['grant_type'], 'password');
        return reply(token('fresh-owner'));
      }),
    );
    await auth.signIn(email, password);
    Future<void> remove() => auth.deleteAccount(
      password: password,
      deletePrivateData: (uid, access) async {
        expect(uid, userId);
        expect(access, 'fresh-owner');
        privateCalls++;
        if (fail) {
          throw const AppFailure(
            'account_delete_unavailable',
            'Synthetic failure',
          );
        }
      },
      deleteLocalData: () async {
        localCalls++;
      },
    );
    await expectLater(remove(), throwsA(isA<AppFailure>()));
    expect(localCalls, 0);
    expect(auth.identity?.uid, userId);
    fail = false;
    await remove();
    expect(privateCalls, 2);
    expect(localCalls, 1);
    expect(auth.identity, isNull);
  });

  test(
    'password change reauthenticates and rotates only the same account',
    () async {
      var signins = 0;
      final auth = account(
        api((request) async {
          if (request.method == 'PUT') {
            expect(request.headers['authorization'], 'Bearer reauthenticated');
            expect(jsonDecode(request.body), {'password': 'NewPassword123!'});
            return reply(user());
          }
          if (request.url.queryParameters['grant_type'] == 'refresh_token') {
            expect(jsonDecode(request.body), {
              'refresh_token': 'refresh-reauthenticated',
            });
            return reply(token('rotated-after-password'));
          }
          signins++;
          return reply(token(signins == 1 ? 'owner' : 'reauthenticated'));
        }),
      );
      await auth.signIn(email, password);
      await auth.changePassword(password, 'NewPassword123!');
      expect(signins, 2);
      expect(auth.identity?.uid, userId);
      expect(await auth.token(userId), 'rotated-after-password');
    },
  );

  test(
    'recovery links use the web password form rather than the sign-in return',
    () async {
      final auth = SelfhostAccountAuth(
        client: api((request) async {
          expect(request.url.path, '/auth/v1/recover');
          expect(
            request.url.queryParameters['redirect_to'],
            'https://frontend.example.test/account-recovery.html',
          );
          return reply({});
        }),
        emailRedirect: Uri.parse(
          'https://frontend.example.test/#/account-signin',
        ),
        recoveryRedirect: Uri.parse(
          'https://frontend.example.test/account-recovery.html',
        ),
      );
      addTearDown(auth.dispose);
      await auth.resetPassword(email);
      expect(auth.identity, isNull);
    },
  );
}

final class MemorySelfhostAccountSessionStorage
    implements SelfhostAccountSessionStorage {
  MemorySelfhostAccountSessionStorage([this.session]);

  StoredSelfhostAccountSession? session;

  @override
  Future<StoredSelfhostAccountSession?> read() async => session;

  @override
  Future<void> write(StoredSelfhostAccountSession value) async {
    session = value;
  }

  @override
  Future<void> delete() async {
    session = null;
  }
}
