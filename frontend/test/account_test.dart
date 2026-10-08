import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unlabel/app/unlabel_theme.dart';
import 'package:unlabel/core/accounts/account_auth.dart';
import 'package:unlabel/core/accounts/account_controller.dart';
import 'package:unlabel/core/accounts/account_data.dart';
import 'package:unlabel/core/accounts/account_store.dart';
import 'package:unlabel/core/accounts/account_sync_api.dart';
import 'package:unlabel/core/models/app_failure.dart';
import 'package:unlabel/core/models/product_report.dart';
import 'package:unlabel/core/storage/local_store.dart';
import 'package:unlabel/features/account/data/device_profile_preferences.dart';
import 'package:unlabel/features/account/presentation/profile_page.dart';

class MemoryPreferences implements PreferencesAdapter {
  final values = <String, String>{};
  bool fail = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    if (fail) throw StateError('Synthetic disk failure');
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async => values.remove(key);
}

class FakeAuth extends AccountAuth {
  AccountIdentity? current;
  Completer<String>? tokenWait;
  int signIns = 0;
  int resets = 0;
  @override
  AccountIdentity? get identity => current;
  void setUser(String? uid) {
    current = uid == null
        ? null
        : AccountIdentity(uid: uid, email: 'synthetic@example.invalid');
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
  Future<void> resetPassword(String email) async {
    resets++;
  }

  @override
  Future<void> signOut() async => setUser(null);
  @override
  Future<String> token(String expectedUid) async =>
      tokenWait == null ? 'synthetic-token-$expectedUid' : tokenWait!.future;
}

class FakeSync implements AccountSyncTransport {
  AccountSnapshot cloud = AccountSnapshot(revision: 0, data: AccountData());
  final mutations = <AccountMutation>[];
  bool enabled = true;
  bool failPut = false;
  bool conflictPut = false;
  int fetches = 0;
  Completer<AccountSnapshot>? fetchWait;
  Completer<AccountSnapshot>? putWait;
  @override
  Future<bool> available() async => enabled;
  @override
  Future<AccountSnapshot> fetch(String token) async {
    fetches++;
    return fetchWait == null ? cloud : fetchWait!.future;
  }

  @override
  Future<AccountSnapshot> put(String token, AccountMutation mutation) async {
    mutations.add(mutation);
    if (failPut) {
      throw const AppFailure('sync_network', 'Synthetic connection failure.');
    }
    if (conflictPut || mutation.expectedRevision != cloud.revision) {
      throw const AppFailure('sync_conflict', 'Synthetic conflict.');
    }
    if (putWait != null) return putWait!.future;
    cloud = AccountSnapshot(
      revision: cloud.revision + 1,
      data: mutation.data,
      updatedAt: DateTime.utc(2026, 10, 7),
    );
    return cloud;
  }

  @override
  void cancelAll() {}
  @override
  void close() {}
}

ProductReport report() => ProductReport.fromJson(
  jsonDecode(
    File('../contracts/examples/label-report-v1.current.synthetic.json')
        .readAsStringSync(),
  ) as JsonMap,
);
Matcher failure(String kind) =>
    isA<AppFailure>().having((e) => e.kind, 'kind', kind);

Future<AccountController> controller(
  MemoryPreferences prefs,
  FakeAuth auth,
  FakeSync api,
) async {
  final result = AccountController(
    auth: auth,
    api: api,
    guestStore: LocalStore(preferences: prefs),
    preferences: prefs,
    debounce: const Duration(days: 1),
  );
  await result.start();
  if (auth.identity != null) await result.refreshSync();
  return result;
}

void main() {
  group('strict personal contract', () {
    test('parses the real backend sync snapshot export', () {
      final raw = jsonDecode(
        File('../contracts/examples/personal-sync-v1.snapshot.synthetic.json')
            .readAsStringSync(),
      ) as JsonMap;
      final value = AccountSnapshot.fromJson(raw);
      expect(value.revision, greaterThanOrEqualTo(0));
      expect(value.data.saved.length, lessThanOrEqualTo(50));
    });
    test('rejects unknown personal fields and duplicate UUIDs', () {
      expect(
        () => AccountData.fromJson({
          'profile': {'display_name': null},
          'saved': [],
          'history': [],
          'email': 'private',
        }),
        throwsA(failure('invalid_response')),
      );
      final entry = AccountEntry(
        entryId: '11111111-1111-4111-8111-111111111111',
        recordedAt: DateTime.utc(2026, 10, 7),
        report: report(),
      ).toJson();
      expect(
        () => AccountData.fromJson({
          'profile': {'display_name': null},
          'saved': [entry, entry],
          'history': [],
        }),
        throwsA(failure('invalid_response')),
      );
    });
    test('acknowledgement compares meaning without changing retry bytes', () {
      final raw = jsonDecode(jsonEncode(report().raw)) as JsonMap;
      final original = AccountData(
        saved: [
          AccountEntry(
            entryId: '11111111-1111-4111-8111-111111111111',
            recordedAt: DateTime.utc(2026, 10, 7),
            report: ProductReport.fromJson(raw),
          ),
        ],
      );
      final reordered = Map<String, dynamic>.fromEntries(
        raw.entries.toList().reversed,
      );
      reordered['generated_at'] = DateTime.parse(raw['generated_at'] as String)
          .toUtc()
          .toIso8601String();
      final returned = AccountData(
        saved: [
          AccountEntry(
            entryId: original.saved.single.entryId,
            recordedAt: original.saved.single.recordedAt,
            report: ProductReport.fromJson(reordered),
          ),
        ],
      );
      final bytes = original.encoded;
      expect(original.sameContent(returned), true);
      expect(original.encoded, bytes);
      expect(
        original.sameContent(original.copyWith(displayName: 'Different')),
        false,
      );
    });
    test(
      'historical report timestamp normalization keeps acknowledgements equal',
      () {
        final original = jsonDecode(
          File(
            '../contracts/examples/label-report-v1.historical.synthetic.json',
          ).readAsStringSync(),
        ) as JsonMap;
        final timestampKeys = {
          'generated_at',
          'recorded_at',
          'observed_at',
          'updated_at',
          'retrieved_at',
          'assessed_at',
          'submitted_at',
          'reviewed_at',
          'expires_at',
          'source_updated_at',
          'exported_at',
          'indexed_at',
          'last_modified_at',
          'provider_modified_at',
          'normalized_at',
        };
        Object? change(Object? value, [String? key]) {
          if (value is Map<String, dynamic>) {
            return value.map((k, v) => MapEntry(k, change(v, k)));
          }
          if (value is List) return value.map(change).toList();
          if (value is String && timestampKeys.contains(key)) {
            final at = DateTime.tryParse(value);
            if (at != null) {
              return at.toUtc().toIso8601String().replaceFirst('Z', '+00:00');
            }
          }
          return value;
        }

        AccountData data(JsonMap raw) => AccountData(
          saved: [
            AccountEntry(
              entryId: '11111111-1111-4111-8111-111111111111',
              recordedAt: DateTime.utc(2026, 10, 7),
              report: ProductReport.fromJson(raw),
            ),
          ],
        );
        expect(
          data(original).sameContent(data(change(original) as JsonMap)),
          true,
        );
      },
    );
    test('oversized sync data is rejected without silently trimming entries', () {
      final data = AccountData(
        history: List.generate(
          100,
          (index) => AccountEntry(
            entryId:
                '22222222-2222-4222-8222-${index.toString().padLeft(12, '0')}',
            recordedAt: DateTime.utc(2026, 10, 7),
            report: report(),
          ),
        ),
        saved: List.generate(
          50,
          (index) => AccountEntry(
            entryId:
                '11111111-1111-4111-8111-${index.toString().padLeft(12, '0')}',
            recordedAt: DateTime.utc(2026, 10, 7),
            report: report(),
          ),
        ),
      );
      expect(() => data.checkSyncSize(), throwsA(failure('sync_capacity')));
      expect(data.saved, hasLength(50));
    });
  });

  group('guest and account isolation', () {
    test(
      'guest use makes no sync request and sign-in never imports guest reports',
      () async {
        final prefs = MemoryPreferences();
        final auth = FakeAuth();
        final api = FakeSync();
        final value = await controller(prefs, auth, api);
        addTearDown(value.dispose);
        await value.guestStore.save(report());
        expect(api.fetches, 0);
        expect(value.activeStore, same(value.guestStore));
        await value.signIn('synthetic@example.invalid', 'unused-synthetic');
        await value.refreshSync();
        expect(await value.activeStore.saved(), isEmpty);
        expect(await value.guestStore.saved(), hasLength(1));
        expect(api.mutations, isEmpty);
        await value.copyGuestLibrary();
        await value.refreshSync();
        expect(api.cloud.data.saved, hasLength(1));
        expect(await value.guestStore.saved(), hasLength(1));
        expect(prefs.values.values.join(), isNot(contains('synthetic-token')));
        expect(
          prefs.values.values.join(),
          isNot(contains('synthetic@example.invalid')),
        );
      },
    );
    test(
      'account switch and logout select different persistent libraries',
      () async {
        final prefs = MemoryPreferences();
        final auth = FakeAuth()..setUser('account-a');
        final api = FakeSync();
        final value = await controller(prefs, auth, api);
        addTearDown(value.dispose);
        await value.activeStore.save(report());
        expect(await value.activeStore.saved(), hasLength(1));
        auth.setUser('account-b');
        await value.refreshSync();
        expect(await value.activeStore.saved(), isEmpty);
        await value.signOut();
        expect(value.activeStore, same(value.guestStore));
        expect(await value.activeStore.saved(), isEmpty);
        final a = AccountStore(uid: 'account-a', preferences: prefs);
        expect(await a.saved(), hasLength(1));
      },
    );
    test(
      'late cloud response after sign-out never changes guest storage or state',
      () async {
        final prefs = MemoryPreferences();
        final auth = FakeAuth()..setUser('account-a');
        final api = FakeSync()..fetchWait = Completer();
        final value = AccountController(
          auth: auth,
          api: api,
          guestStore: LocalStore(preferences: prefs),
          preferences: prefs,
        );
        addTearDown(value.dispose);
        await value.start();
        final pending = value.refreshSync();
        await Future<void>.delayed(Duration.zero);
        await value.signOut();
        api.fetchWait!.complete(
          AccountSnapshot(
            revision: 5,
            data: AccountData(displayName: 'Old account'),
            updatedAt: DateTime.utc(2026, 10, 7),
          ),
        );
        await pending;
        expect(value.state, AccountSyncState.guest);
        expect(value.identity, isNull);
        expect(await value.guestStore.saved(), isEmpty);
        expect(prefs.values, isEmpty);
      },
    );
  });

  group('sync revisions and retry boundaries', () {
    test(
      'changed cloud data needs a choice even when this device was clean',
      () async {
        final prefs = MemoryPreferences();
        final auth = FakeAuth()..setUser('account-a');
        final api = FakeSync();
        final value = await controller(prefs, auth, api);
        addTearDown(value.dispose);
        api.cloud = AccountSnapshot(
          revision: 1,
          data: AccountData(displayName: 'Changed elsewhere'),
          updatedAt: DateTime.utc(2026, 10, 7),
        );
        await value.refreshSync();
        expect(value.state, AccountSyncState.needsChoice);
        expect((await value.accountStore!.snapshot()).data.displayName, isNull);
      },
    );
    test('guest copy cannot overwrite changes made after checking the empty library', () async {
      final prefs = MemoryPreferences();
      final store = AccountStore(uid: 'account-a', preferences: prefs);
      final before = await store.snapshot();
      await store.setDisplayName('New account edit');
      await expectLater(
        store.copyIntoEmpty(
          AccountData(),
          expectedLocalRevision: before.localRevision,
        ),
        throwsA(failure('sync_changed')),
      );
      expect((await store.snapshot()).data.displayName, 'New account edit');
    });
    test('first existing cloud library needs explicit choice, then no polling loop', () async {
      final prefs = MemoryPreferences();
      final auth = FakeAuth()..setUser('account-a');
      final api = FakeSync()
        ..cloud = AccountSnapshot(
          revision: 2,
          data: AccountData(displayName: 'Cloud name'),
          updatedAt: DateTime.utc(2026, 10, 7),
        );
      final value = await controller(prefs, auth, api);
      addTearDown(value.dispose);
      expect(value.state, AccountSyncState.needsChoice);
      expect((await value.accountStore!.snapshot()).data.displayName, isNull);
      await value.useCloud();
      expect(
        (await value.accountStore!.snapshot()).data.displayName,
        'Cloud name',
      );
      expect(value.state, AccountSyncState.ready);
      final readCount = api.fetches;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(api.fetches, readCount);
    });
    test('uncertain upload retry retains exact mutation UUID across controller restart', () async {
      final prefs = MemoryPreferences();
      final auth = FakeAuth()..setUser('account-a');
      final api = FakeSync();
      final first = await controller(prefs, auth, api);
      await first.activeStore.save(report());
      api.failPut = true;
      await first.refreshSync();
      expect(first.state, AccountSyncState.failed);
      final attempted = api.mutations.single;
      first.dispose();
      api.failPut = false;
      final second = await controller(prefs, auth, api);
      addTearDown(second.dispose);
      expect(api.mutations, hasLength(2));
      expect(api.mutations.last.id, attempted.id);
      expect(
        jsonEncode(api.mutations.last.toJson()),
        jsonEncode(attempted.toJson()),
      );
      expect(second.state, AccountSyncState.ready);
    });
    test(
      'a remotely completed uncertain upload is acknowledged without replay',
      () async {
        final prefs = MemoryPreferences();
        final auth = FakeAuth()..setUser('account-a');
        final api = FakeSync();
        final value = await controller(prefs, auth, api);
        addTearDown(value.dispose);
        await value.activeStore.save(report());
        api.failPut = true;
        await value.refreshSync();
        final pending = api.mutations.single;
        api.cloud = AccountSnapshot(
          revision: 1,
          data: pending.data,
          updatedAt: DateTime.utc(2026, 10, 7),
        );
        api.failPut = false;
        await value.refreshSync();
        expect(api.mutations, hasLength(1));
        expect((await value.accountStore!.snapshot()).pending, isNull);
        expect((await value.accountStore!.snapshot()).dirty, false);
      },
    );
    test('remote changes and dirty local data are never blindly merged or replaced', () async {
      final prefs = MemoryPreferences();
      final auth = FakeAuth()..setUser('account-a');
      final api = FakeSync();
      final value = await controller(prefs, auth, api);
      addTearDown(value.dispose);
      await value.updateDisplayName('Device name');
      api.cloud = AccountSnapshot(
        revision: 2,
        data: AccountData(displayName: 'Cloud name'),
        updatedAt: DateTime.utc(2026, 10, 7),
      );
      await value.refreshSync();
      expect(value.state, AccountSyncState.needsChoice);
      expect(
        (await value.accountStore!.snapshot()).data.displayName,
        'Device name',
      );
      expect(api.mutations, isEmpty);
      await value.useDevice();
      expect(api.mutations.single.expectedRevision, 2);
      expect(api.cloud.data.displayName, 'Device name');
    });
    test(
      'device edits after conflict invalidate an older replace choice',
      () async {
        final prefs = MemoryPreferences();
        final auth = FakeAuth()..setUser('account-a');
        final api = FakeSync()
          ..cloud = AccountSnapshot(
            revision: 1,
            data: AccountData(displayName: 'Cloud name'),
            updatedAt: DateTime.utc(2026, 10, 7),
          );
        final value = await controller(prefs, auth, api);
        addTearDown(value.dispose);
        await value.updateDisplayName('New local edit');
        await expectLater(value.useCloud(), throwsA(failure('sync_changed')));
        expect(
          (await value.accountStore!.snapshot()).data.displayName,
          'New local edit',
        );
      },
    );
    test(
      'CAS failure fetches remote data and exposes explicit conflict choices',
      () async {
        final prefs = MemoryPreferences();
        final auth = FakeAuth()..setUser('account-a');
        final api = FakeSync();
        final value = await controller(prefs, auth, api);
        addTearDown(value.dispose);
        await value.updateDisplayName('Device');
        api.conflictPut = true;
        await value.refreshSync();
        expect(value.state, AccountSyncState.needsChoice);
        expect(
          (await value.accountStore!.snapshot()).data.displayName,
          'Device',
        );
      },
    );
    test(
      'edits during upload remain dirty after the older acknowledged snapshot',
      () async {
        final prefs = MemoryPreferences();
        final auth = FakeAuth()..setUser('account-a');
        final api = FakeSync();
        final value = await controller(prefs, auth, api);
        addTearDown(value.dispose);
        await value.updateDisplayName('First');
        api.putWait = Completer();
        final pending = value.refreshSync();
        while (api.mutations.isEmpty) {
          await Future<void>.delayed(Duration.zero);
        }
        final sent = api.mutations.single;
        await value.updateDisplayName('Second');
        api.putWait!.complete(
          AccountSnapshot(
            revision: 1,
            data: sent.data,
            updatedAt: DateTime.utc(2026, 10, 7),
          ),
        );
        await pending;
        final cache = await value.accountStore!.snapshot();
        expect(cache.data.displayName, 'Second');
        expect(cache.dirty, true);
        expect(cache.cloudRevision, 1);
      },
    );
    test(
      'clear keeps a versioned empty snapshot and leaves guest copies alone',
      () async {
        final prefs = MemoryPreferences();
        final auth = FakeAuth()..setUser('account-a');
        final api = FakeSync();
        final value = await controller(prefs, auth, api);
        addTearDown(value.dispose);
        await value.guestStore.save(report());
        await value.activeStore.save(report());
        await value.refreshSync();
        await value.clearAccountLibrary();
        expect(api.cloud.data.isEmpty, true);
        expect(api.cloud.revision, 2);
        expect(await value.guestStore.saved(), hasLength(1));
      },
    );
    test(
      'local persistence failure never uploads an unpersisted mutation',
      () async {
        final prefs = MemoryPreferences();
        final auth = FakeAuth()..setUser('account-a');
        final api = FakeSync();
        final value = await controller(prefs, auth, api);
        addTearDown(value.dispose);
        await value.updateDisplayName('Device');
        prefs.fail = true;
        await value.refreshSync();
        expect(value.state, AccountSyncState.failed);
        expect(api.mutations, isEmpty);
      },
    );
  });

  group('bounded private HTTP', () {
    test(
      'no automatic auth replay or redirect, and provider bodies stay redacted',
      () async {
        var calls = 0;
        final api = AccountSyncApi(
          baseUrl: 'https://example.invalid',
          client: MockClient((request) async {
            calls++;
            expect(request.followRedirects, false);
            expect(request.headers['Authorization'], 'Bearer synthetic-token');
            return http.Response('{"private":"never display this"}', 401);
          }),
        );
        addTearDown(api.close);
        await expectLater(
          api.fetch('synthetic-token'),
          throwsA(failure('account_authentication')),
        );
        expect(calls, 1);
      },
    );
    test('rejects invalid secure origins and oversized responses', () async {
      expect(
        () => AccountSyncApi(baseUrl: 'https://example.invalid/?token=private'),
        throwsA(failure('invalid_configuration')),
      );
      expect(
        () =>
            AccountSyncApi(baseUrl: 'http://lan.invalid', allowLocalHttp: true),
        throwsA(failure('invalid_configuration')),
      );
      final api = AccountSyncApi(
        baseUrl: 'https://example.invalid',
        client: MockClient(
          (_) async =>
              http.Response('x' * (AccountSyncApi.maxResponseBytes + 1), 200),
        ),
      );
      addTearDown(api.close);
      await expectLater(
        api.fetch('synthetic-token'),
        throwsA(failure('invalid_response')),
      );
    });
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'guest profile remains optional and usable at 320px/2x $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final prefs = MemoryPreferences();
        final auth = FakeAuth();
        final api = FakeSync();
        final value = await controller(prefs, auth, api);
        var continued = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: UnlabelTheme.forBrightness(brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: ProfilePage(
              controller: value,
              onContinue: () => continued = true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Continue as guest'), findsNothing);
        expect(continued, false);
        expect(api.fetches, 0);
        await tester.ensureVisible(find.text('Sign in'));
        await tester.tap(find.text('Sign in'));
        await tester.pumpAndSettle();
        expect(find.text('Welcome back'), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const ValueKey('account-submit')),
        );
        await tester.tap(find.byKey(const ValueKey('account-submit')));
        await tester.pumpAndSettle();
        expect(find.text('Enter a valid email address.'), findsOneWidget);
        expect(auth.signIns, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        value.dispose();
        auth.dispose();
      },
    );
  }
  testWidgets(
    'profile counts active reports and keeps reminders device-local',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final prefs = MemoryPreferences();
      final auth = FakeAuth();
      final api = FakeSync();
      final value = await controller(prefs, auth, api);
      addTearDown(value.dispose);
      addTearDown(auth.dispose);
      await value.activeStore.record(report());
      await value.activeStore.save(report());
      await tester.pumpWidget(
        MaterialApp(
          theme: UnlabelTheme.forBrightness(Brightness.light),
          home: ProfilePage(controller: value, onContinue: () {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1'), findsNWidgets(2));
      expect(find.text('128'), findsNothing);
      expect(find.text('—'), findsOneWidget);
      await tester.ensureVisible(find.text('Preferences'));
      await tester.tap(find.text('Preferences'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Low sugar'));
      await tester.tap(find.text('Save preferences'));
      await tester.pumpAndSettle();
      expect(
        (await DeviceProfilePreferencesStore(prefs).read()).lowSugar,
        true,
      );
      expect(api.fetches, 0);
      expect(api.mutations, isEmpty);
      await tester.ensureVisible(find.text('Allergens'));
      await tester.tap(find.text('Allergens'));
      await tester.pumpAndSettle();
      expect(find.text('Allergen reminders'), findsOneWidget);
      await tester.tap(find.text('Milk'));
      await tester.tap(find.text('Save allergens'));
      await tester.pumpAndSettle();
      expect((await DeviceProfilePreferencesStore(prefs).read()).allergens, {
        'milk',
      });
      expect(api.mutations, isEmpty);
      await tester.ensureVisible(find.text('Notifications'));
      final notificationSwitch = tester.widget<Switch>(
        find.byType(Switch).first,
      );
      expect(notificationSwitch.value, false);
      expect(notificationSwitch.onChanged, isNull);
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Push notifications and reminders are not supported in this version.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'profile Privacy preserves explicit sync choice and clear controls',
    (tester) async {
      final prefs = MemoryPreferences();
      final auth = FakeAuth()..setUser('account-a');
      final api = FakeSync()
        ..cloud = AccountSnapshot(
          revision: 2,
          data: AccountData(displayName: 'Synthetic cloud name'),
        );
      final value = await controller(prefs, auth, api);
      addTearDown(value.dispose);
      addTearDown(auth.dispose);
      expect(value.state, AccountSyncState.needsChoice);
      await tester.pumpWidget(
        MaterialApp(
          theme: UnlabelTheme.forBrightness(Brightness.light),
          home: ProfilePage(controller: value, onContinue: () {}),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose your sync library'));
      await tester.pumpAndSettle();
      expect(find.text('Use cloud library'), findsOneWidget);
      expect(find.text('Use this device library'), findsOneWidget);
      await tester.tap(find.text('Use cloud library'));
      await tester.pumpAndSettle();
      expect(find.text('Use the cloud library?'), findsOneWidget);
      expect(api.mutations, isEmpty);
      await tester.tap(find.text('Use cloud'));
      await tester.pumpAndSettle();
      expect(value.localData!.displayName, 'Synthetic cloud name');
      expect(value.state, AccountSyncState.ready);
      await tester.ensureVisible(find.text('Clear account data'));
      await tester.tap(find.text('Clear account data'));
      await tester.pumpAndSettle();
      expect(find.text('Clear account data?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(value.localData!.displayName, 'Synthetic cloud name');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'account help exposes creation and password reset before failure',
    (tester) async {
      final prefs = MemoryPreferences();
      final auth = FakeAuth();
      final value = await controller(prefs, auth, FakeSync());
      addTearDown(value.dispose);
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: UnlabelTheme.forBrightness(Brightness.light),
          home: ProfilePage(controller: value, onContinue: () {}),
        ),
      );
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email address'),
        'synthetic@example.invalid',
      );
      await tester.tap(find.text('Account help'));
      await tester.pumpAndSettle();
      expect(find.text('Reset password'), findsOneWidget);
      expect(find.text('Create an account'), findsOneWidget);
      await tester.tap(find.text('Reset password'));
      await tester.pumpAndSettle();
      expect(auth.resets, 1);
      expect(auth.signIns, 0);
      await tester.ensureVisible(find.text('Account help'));
      await tester.tap(find.text('Account help'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();
      expect(find.text('Create your account'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'synthetic-password',
      );
      await tester.tap(find.byKey(const ValueKey('account-submit')));
      await tester.pumpAndSettle();
      expect(value.identity, isNotNull);
      expect(find.text('Welcome back'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'signed-in profile name and appearance actions work at 320px/2x',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final prefs = MemoryPreferences();
      final auth = FakeAuth()..setUser('account-a');
      final value = await controller(prefs, auth, FakeSync());
      var appearance = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: UnlabelTheme.forBrightness(Brightness.dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: ProfilePage(
            controller: value,
            onContinue: () {},
            onAppearance: () => appearance = true,
            onAbout: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Edit profile'));
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Synthetic name');
      await tester.tap(find.text('Save name'));
      await tester.pumpAndSettle();
      expect(value.localData!.displayName, 'Synthetic name');
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Dark mode'));
      await tester.tap(find.text('Dark mode'));
      await tester.pumpAndSettle();
      expect(appearance, true);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      value.dispose();
      auth.dispose();
    },
  );
}
