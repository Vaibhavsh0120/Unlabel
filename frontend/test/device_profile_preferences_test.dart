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

  test(
    'existing v1 reminders read without rewriting and migrate on Save',
    () async {
      final preferences = _Preferences();
      final legacy = jsonEncode({
        'schema_version': '1',
        'low_sugar': true,
        'high_fibre': false,
        'vegetarian': true,
        'allergens': ['milk', 'soy'],
      });
      preferences.values[DeviceProfilePreferencesStore.key] = legacy;
      final store = DeviceProfilePreferencesStore(preferences);
      final restored = await store.read();
      expect(restored.lowSugar, true);
      expect(restored.vegetarian, true);
      expect(restored.allergens, {'milk', 'soy'});
      expect(restored.extraPreferences, isEmpty);
      expect(preferences.values[DeviceProfilePreferencesStore.key], legacy);
      await store.write(restored.copyWith(extraPreferences: {'high_protein'}));
      final written = jsonDecode(
        preferences.values[DeviceProfilePreferencesStore.key]!,
      );
      expect(written['schema_version'], '2');
      expect(written['extra_preferences'], ['high_protein']);
      final migrated = await store.read();
      expect(migrated.lowSugar, true);
      expect(migrated.vegetarian, true);
      expect(migrated.allergens, {'milk', 'soy'});
      expect(migrated.extraPreferences, {'high_protein'});
    },
  );

  test(
    'v2 round trip retains all eight preferences and twelve allergens',
    () async {
      final preferences = _Preferences();
      final store = DeviceProfilePreferencesStore(preferences);
      await store.write(
        DeviceProfilePreferences(
          lowSugar: true,
          highFibre: true,
          vegetarian: true,
          extraPreferences: DeviceProfilePreferences.extraPreferenceLabels.keys
              .toSet(),
          allergens: DeviceProfilePreferences.allergenLabels.keys.toSet(),
        ),
      );
      final restored = await store.read();
      expect(restored.selectedPreferenceLabels.length, 8);
      expect(restored.extraPreferences.length, 5);
      expect(restored.allergens.length, 12);
      final allergenOnlyChange = restored.copyWith(
        allergens: {'celery', 'sulphites'},
      );
      expect(allergenOnlyChange.extraPreferences, restored.extraPreferences);
      expect(allergenOnlyChange.lowSugar, true);
      final foodOnlyChange = restored.copyWith(extraPreferences: {'vegan'});
      expect(foodOnlyChange.allergens, restored.allergens);
      expect(preferences.values.keys, {DeviceProfilePreferencesStore.key});
    },
  );

  test('invalid new preferences fail without replacing stored data', () async {
    final preferences = _Preferences();
    final store = DeviceProfilePreferencesStore(preferences);
    await store.write(
      const DeviceProfilePreferences(extraPreferences: {'vegan'}),
    );
    final valid = preferences.values[DeviceProfilePreferencesStore.key];
    final base = jsonDecode(valid!) as Map<String, dynamic>;
    for (final invalid in [
      {...base}..remove('extra_preferences'),
      {
        ...base,
        'extra_preferences': ['vegan', 'vegan'],
      },
      {
        ...base,
        'extra_preferences': ['unsupported'],
      },
      {...base, 'extra_preferences': 'vegan'},
      {...base, 'schema_version': '3'},
      {...base, 'unexpected': true},
      {...base, 'schema_version': '1'},
    ]) {
      final encoded = jsonEncode(invalid);
      preferences.values[DeviceProfilePreferencesStore.key] = encoded;
      await expectLater(
        store.read(),
        throwsA(
          isA<AppFailure>().having(
            (failure) => failure.kind,
            'kind',
            'local_data_corrupt',
          ),
        ),
      );
      expect(preferences.values[DeviceProfilePreferencesStore.key], encoded);
    }
    preferences.values[DeviceProfilePreferencesStore.key] = valid;
    await expectLater(
      store.write(
        const DeviceProfilePreferences(extraPreferences: {'unsupported'}),
      ),
      throwsA(
        isA<AppFailure>().having(
          (failure) => failure.kind,
          'kind',
          'invalid_input',
        ),
      ),
    );
    expect(preferences.values[DeviceProfilePreferencesStore.key], valid);
  });
}
