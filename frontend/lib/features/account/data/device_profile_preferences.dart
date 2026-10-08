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
    this.extraPreferences = const {},
  });

  final bool lowSugar, highFibre, vegetarian;
  final Set<String> allergens, extraPreferences;

  static const extraPreferenceLabels = <String, String>{
    'high_protein': 'Higher protein',
    'low_sodium': 'Lower sodium',
    'low_saturated_fat': 'Less saturated fat',
    'no_added_sugar': 'No added sugar',
    'vegan': 'Vegan',
  };

  List<String> get selectedPreferenceLabels => [
    if (lowSugar) 'Low sugar',
    if (highFibre) 'High fibre',
    if (vegetarian) 'Vegetarian',
    for (final preference in extraPreferenceLabels.entries)
      if (extraPreferences.contains(preference.key)) preference.value,
  ];

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
    'mustard': 'Mustard',
    'celery': 'Celery',
    'sulphites': 'Sulphites',
  };

  DeviceProfilePreferences copyWith({
    bool? lowSugar,
    bool? highFibre,
    bool? vegetarian,
    Set<String>? allergens,
    Set<String>? extraPreferences,
  }) => DeviceProfilePreferences(
    lowSugar: lowSugar ?? this.lowSugar,
    highFibre: highFibre ?? this.highFibre,
    vegetarian: vegetarian ?? this.vegetarian,
    allergens: Set.unmodifiable(allergens ?? this.allergens),
    extraPreferences: Set.unmodifiable(
      extraPreferences ?? this.extraPreferences,
    ),
  );

  Map<String, Object> toJson() => {
    'schema_version': '2',
    'low_sugar': lowSugar,
    'high_fibre': highFibre,
    'vegetarian': vegetarian,
    'allergens': allergens.toList()..sort(),
    'extra_preferences': extraPreferences.toList()..sort(),
  };

  factory DeviceProfilePreferences.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid device preferences');
    }
    final version = value['schema_version'];
    if (!const {'1', '2'}.contains(version) ||
        value.keys.toSet().difference({
          'schema_version',
          'low_sugar',
          'high_fibre',
          'vegetarian',
          'allergens',
          if (version == '2') 'extra_preferences',
        }).isNotEmpty ||
        value['low_sugar'] is! bool ||
        value['high_fibre'] is! bool ||
        value['vegetarian'] is! bool ||
        value['allergens'] is! List ||
        (version == '2' && value['extra_preferences'] is! List)) {
      throw const FormatException('Invalid device preferences');
    }
    final allergens = value['allergens'] as List;
    final extraPreferences = version == '2'
        ? value['extra_preferences'] as List
        : const [];
    if (allergens.length > allergenLabels.length ||
        allergens.any((item) => !allergenLabels.containsKey(item)) ||
        allergens.toSet().length != allergens.length) {
      throw const FormatException('Invalid allergen reminders');
    }
    if (extraPreferences.length > extraPreferenceLabels.length ||
        extraPreferences.any(
          (item) => !extraPreferenceLabels.containsKey(item),
        ) ||
        extraPreferences.toSet().length != extraPreferences.length) {
      throw const FormatException('Invalid food preferences');
    }
    return DeviceProfilePreferences(
      lowSugar: value['low_sugar'] as bool,
      highFibre: value['high_fibre'] as bool,
      vegetarian: value['vegetarian'] as bool,
      allergens: Set.unmodifiable(allergens.cast<String>()),
      extraPreferences: Set.unmodifiable(extraPreferences.cast<String>()),
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
