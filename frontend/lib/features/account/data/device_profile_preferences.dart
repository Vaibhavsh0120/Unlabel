import 'dart:convert';

import '../../../core/models/app_failure.dart';
import '../../../core/storage/local_store.dart';

/// Personal reminders belong to this device, never private account sync or
/// public package observations. They do not classify foods or establish safety.
class DeviceProfilePreferences {
  const DeviceProfilePreferences({
    this.lowSugar = false,
    this.highFibre = false,
    this.vegetarian = false,
    this.allergens = const {},
  });

  final bool lowSugar, highFibre, vegetarian;
  final Set<String> allergens;

  static const allergenLabels = <String, String>{
    'milk': 'Milk',
    'gluten': 'Gluten',
    'eggs': 'Eggs',
    'peanuts': 'Peanuts',
    'tree_nuts': 'Tree nuts',
    'soy': 'Soy',
    'fish': 'Fish',
    'shellfish': 'Shellfish',
    'sesame': 'Sesame',
  };

  DeviceProfilePreferences copyWith({
    bool? lowSugar,
    bool? highFibre,
    bool? vegetarian,
    Set<String>? allergens,
  }) => DeviceProfilePreferences(
    lowSugar: lowSugar ?? this.lowSugar,
    highFibre: highFibre ?? this.highFibre,
    vegetarian: vegetarian ?? this.vegetarian,
    allergens: Set.unmodifiable(allergens ?? this.allergens),
  );

  Map<String, Object> toJson() => {
    'schema_version': '1',
    'low_sugar': lowSugar,
    'high_fibre': highFibre,
    'vegetarian': vegetarian,
    'allergens': allergens.toList()..sort(),
  };

  factory DeviceProfilePreferences.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value.keys.toSet().difference({
          'schema_version',
          'low_sugar',
          'high_fibre',
          'vegetarian',
          'allergens',
        }).isNotEmpty ||
        value['schema_version'] != '1' ||
        value['low_sugar'] is! bool ||
        value['high_fibre'] is! bool ||
        value['vegetarian'] is! bool ||
        value['allergens'] is! List) {
      throw const FormatException('Invalid device preferences');
    }
    final allergens = value['allergens'] as List;
    if (allergens.length > allergenLabels.length ||
        allergens.any((item) => !allergenLabels.containsKey(item)) ||
        allergens.toSet().length != allergens.length) {
      throw const FormatException('Invalid allergen reminders');
    }
    return DeviceProfilePreferences(
      lowSugar: value['low_sugar'] as bool,
      highFibre: value['high_fibre'] as bool,
      vegetarian: value['vegetarian'] as bool,
      allergens: Set.unmodifiable(allergens.cast<String>()),
    );
  }
}

class DeviceProfilePreferencesStore {
  const DeviceProfilePreferencesStore(this.preferences);
  final PreferencesAdapter preferences;
  static const key = 'unlabel.client.v1.deviceProfilePreferences';
  static const maxBytes = 1024;

  Future<DeviceProfilePreferences> read() async {
    try {
      final value = await preferences.read(key);
      if (value == null) return const DeviceProfilePreferences();
      if (value.length > maxBytes || utf8.encode(value).length > maxBytes) {
        throw const FormatException('Oversized device preferences');
      }
      return DeviceProfilePreferences.fromJson(jsonDecode(value));
    } on FormatException {
      throw const AppFailure(
        'local_data_corrupt',
        'Your preferences could not be read. Save your choices again to replace them.',
      );
    } catch (_) {
      throw const AppFailure(
        'local_storage',
        'Your preferences could not be read on this device.',
      );
    }
  }

  Future<void> write(DeviceProfilePreferences value) async {
    final json = value.toJson();
    // Revalidate before writing so callers cannot persist unsupported values.
    try {
      DeviceProfilePreferences.fromJson(json);
    } on FormatException {
      throw const AppFailure('invalid_input', 'Choose a supported reminder.');
    }
    try {
      await preferences.write(key, jsonEncode(json));
    } catch (_) {
      throw const AppFailure(
        'local_storage',
        'Your preferences could not be saved. Please try again.',
      );
    }
  }
}
