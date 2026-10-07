import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/core/models/app_failure.dart';
import 'package:unlabel/core/storage/local_store.dart';
import 'package:unlabel/features/account/data/device_profile_preferences.dart';

class _Preferences implements PreferencesAdapter {
  final values = <String, String>{};
  bool fail = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> remove(String key) async => values.remove(key);
  @override
  Future<void> write(String key, String value) async {
    if (fail) throw StateError('Synthetic storage failure');
    values[key] = value;
  }
}

void main() {
  test(
    'device reminders start empty and write only their dedicated key',
    () async {
      final preferences = _Preferences();
      final store = DeviceProfilePreferencesStore(preferences);
      final initial = await store.read();
      expect(initial.lowSugar, false);
      expect(initial.highFibre, false);
      expect(initial.vegetarian, false);
      expect(initial.allergens, isEmpty);
      preferences.values['unrelated'] = 'preserved';
      await store.write(
        initial.copyWith(lowSugar: true, allergens: {'milk', 'soy'}),
      );
      final restored = await DeviceProfilePreferencesStore(preferences).read();
      expect(restored.lowSugar, true);
      expect(restored.allergens, {'milk', 'soy'});
      expect(preferences.values.keys, {
        'unrelated',
        DeviceProfilePreferencesStore.key,
      });
      expect(preferences.values['unrelated'], 'preserved');
    },
  );

  test(
    'corrupt or unsupported reminders do not become empty success',
    () async {
      final preferences = _Preferences();
      final store = DeviceProfilePreferencesStore(preferences);
      for (final value in [
        'invalid json',
        jsonEncode({
          'schema_version': '1',
          'low_sugar': true,
          'high_fibre': false,
          'vegetarian': false,
          'allergens': ['milk', 'milk'],
        }),
        jsonEncode({
          'schema_version': '1',
          'low_sugar': true,
          'high_fibre': false,
          'vegetarian': false,
          'allergens': ['unsupported'],
        }),
        'x' * (DeviceProfilePreferencesStore.maxBytes + 1),
      ]) {
        preferences.values[DeviceProfilePreferencesStore.key] = value;
        await expectLater(
          store.read(),
          throwsA(
            isA<AppFailure>().having(
              (error) => error.kind,
              'kind',
              'local_data_corrupt',
            ),
          ),
        );
        expect(preferences.values[DeviceProfilePreferencesStore.key], value);
      }
    },
  );

  test('failed writes leave prior reminders intact', () async {
    final preferences = _Preferences();
    final store = DeviceProfilePreferencesStore(preferences);
    await store.write(const DeviceProfilePreferences(highFibre: true));
    preferences.fail = true;
    await expectLater(
      store.write(const DeviceProfilePreferences(lowSugar: true)),
      throwsA(
        isA<AppFailure>().having(
          (error) => error.kind,
          'kind',
          'local_storage',
        ),
      ),
    );
    final restored = await store.read();
    expect(restored.highFibre, true);
    expect(restored.lowSugar, false);
  });

  test('unsupported callers cannot persist an allergen setting', () async {
    final preferences = _Preferences();
    final store = DeviceProfilePreferencesStore(preferences);
    await expectLater(
      store.write(const DeviceProfilePreferences(allergens: {'unsupported'})),
      throwsA(
        isA<AppFailure>().having(
          (error) => error.kind,
          'kind',
          'invalid_input',
        ),
      ),
    );
    expect(preferences.values, isEmpty);
  });
}
