import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unlabel/app/unlabel_theme.dart';
import 'package:unlabel/core/accounts/account_auth.dart';
import 'package:unlabel/core/accounts/account_controller.dart';
import 'package:unlabel/core/accounts/account_sync_api.dart';
import 'package:unlabel/core/storage/local_store.dart';
import 'package:unlabel/features/account/data/device_profile_preferences.dart';
import 'package:unlabel/features/account/presentation/profile_page.dart';
import 'package:unlabel/features/scanner/presentation/ui_components.dart';

class _Preferences implements PreferencesAdapter {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
}

class _Harness {
  final preferences = _Preferences();
  final auth = UnavailableAccountAuth();
  late final api = AccountSyncApi(
    baseUrl: 'https://synthetic.example.invalid',
    client: MockClient((_) async {
      requests++;
      return http.Response('{}', 500);
    }),
  );
  late final controller = AccountController(
    auth: auth,
    api: api,
    guestStore: LocalStore(preferences: preferences),
    preferences: preferences,
  );
  int requests = 0;

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(390, 700),
    Brightness brightness = Brightness.light,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() {
      controller.dispose();
      auth.dispose();
    });
    await controller.start();
    await tester.pumpWidget(
      MaterialApp(
        theme: UnlabelTheme.forBrightness(brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: ProfilePage(controller: controller, onContinue: () {}),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, {bool allergensOnly = false}) async {
    final title = find.text(
      allergensOnly ? 'Allergens to remember' : 'Preferences',
    );
    await tester.ensureVisible(title);
    await tester.tap(title);
    await tester.pumpAndSettle();
  }
}

final _dialog = find.byKey(const ValueKey('profile-preferences-dialog'));
final _save = find.byKey(const ValueKey('save-profile-preferences'));

Finder _choice(String label) =>
    find.descendant(of: _dialog, matching: find.text(label));

void _expectPinnedActions(WidgetTester tester, Size size) {
  final rect = tester.getRect(_save);
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(size.height));
  expect(rect.width, greaterThanOrEqualTo(48));
  expect(rect.height, greaterThanOrEqualTo(48));
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('every food and allergen meaning has its own symbol', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.pump(tester);
    await harness.open(tester);
    final foodSymbols = <String>{};
    for (final key in [
      'low-sugar',
      'high-fibre',
      'vegetarian',
      ...DeviceProfilePreferences.extraPreferenceLabels.keys,
    ]) {
      final choice = find.byKey(ValueKey('food-choice-$key'));
      final symbol = find.descendant(
        of: choice,
        matching: find.byType(FeatureIcon),
      );
      expect(symbol, findsOneWidget, reason: key);
      foodSymbols.add(tester.widget<FeatureIcon>(symbol).name);
    }
    expect(foodSymbols, hasLength(8));
    await tester.tap(_choice('Cancel'));
    await tester.pumpAndSettle();
    await harness.open(tester, allergensOnly: true);
    final allergenSymbols = <String>{};
    for (final key in DeviceProfilePreferences.allergenLabels.keys) {
      final choice = find.byKey(ValueKey('allergen-choice-$key'));
      final symbol = find.descendant(
        of: choice,
        matching: find.byType(FeatureIcon),
      );
      expect(symbol, findsOneWidget, reason: key);
      allergenSymbols.add(tester.widget<FeatureIcon>(symbol).name);
    }
    expect(allergenSymbols, hasLength(12));
    expect({...foodSymbols, ...allergenSymbols}, hasLength(20));
    expect(tester.takeException(), isNull);
    expect(harness.requests, 0);
  });

  testWidgets('selected summaries retain the matching choice symbols', (
    tester,
  ) async {
    final harness = _Harness();
    await DeviceProfilePreferencesStore(harness.preferences).write(
      const DeviceProfilePreferences(
        lowSugar: true,
        highFibre: true,
        allergens: {'milk', 'gluten'},
      ),
    );
    await harness.pump(tester);
    String summarySymbol(String label) {
      final chip = find.ancestor(
        of: find.text(label),
        matching: find.byType(ActionChip),
      );
      return tester
          .widget<FeatureIcon>(
            find.descendant(of: chip, matching: find.byType(FeatureIcon)),
          )
          .name;
    }

    final symbols = {
      for (final label in [
        'Low sugar',
        'High fibre',
        'Milk reminder',
        'Gluten reminder',
      ])
        label: summarySymbol(label),
    };
    expect(symbols.values.toSet(), hasLength(4));
    await harness.open(tester);
    for (final label in ['Low sugar', 'High fibre']) {
      final choice = find
          .ancestor(of: _choice(label), matching: find.byType(InkWell))
          .first;
      expect(
        tester
            .widget<FeatureIcon>(
              find.descendant(of: choice, matching: find.byType(FeatureIcon)),
            )
            .name,
        symbols[label],
      );
    }
    await tester.tap(_choice('Cancel'));
    await tester.pumpAndSettle();
    await harness.open(tester, allergensOnly: true);
    for (final label in ['Milk', 'Gluten']) {
      final choice = find
          .ancestor(of: _choice(label), matching: find.byType(InkWell))
          .first;
      expect(
        tester
            .widget<FeatureIcon>(
              find.descendant(of: choice, matching: find.byType(FeatureIcon)),
            )
            .name,
        symbols['$label reminder'],
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty profile summaries have no suggested or selected chips', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.pump(tester);
    expect(find.text('No preferences selected'), findsOneWidget);
    expect(find.text('No allergens selected'), findsOneWidget);
    expect(find.text('Allergens'), findsNothing);
    expect(find.byType(ActionChip), findsNothing);
    expect(find.byType(FilterChip), findsNothing);
    for (final label in ['Preferences', 'Allergens to remember']) {
      final disclosure = find
          .ancestor(of: find.text(label), matching: find.byType(InkWell))
          .first;
      expect(tester.getSize(disclosure).height, greaterThanOrEqualTo(48));
    }
    for (final label in ['Low sugar', 'High fibre', 'Vegetarian']) {
      expect(find.text(label), findsNothing);
    }
    await harness.open(tester);
    expect(_choice('Low sugar'), findsOneWidget);
    await tester.tap(_choice('Cancel'));
    await tester.pumpAndSettle();
    await harness.open(tester, allergensOnly: true);
    expect(_choice('Milk'), findsOneWidget);
    expect(harness.preferences.values, isEmpty);
    expect(harness.requests, 0);
  });

  for (final count in [1, 2]) {
    testWidgets('$count saved choices show without defaults or overflow', (
      tester,
    ) async {
      final harness = _Harness();
      await DeviceProfilePreferencesStore(harness.preferences).write(
        DeviceProfilePreferences(
          extraPreferences: count == 1 ? {'vegan'} : {'vegan', 'low_sodium'},
          allergens: count == 1 ? {'soy'} : {'soy', 'milk'},
        ),
      );
      await harness.pump(tester);
      expect(find.byType(ActionChip), findsNWidgets(count * 2));
      expect(find.text('Vegan'), findsOneWidget);
      expect(find.text('Soy reminder'), findsOneWidget);
      expect(find.text('Low sugar'), findsNothing);
      expect(find.text('High fibre'), findsNothing);
      expect(find.text('Vegetarian'), findsNothing);
      expect(
        find.byKey(const ValueKey('profile-preferences-overflow')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('profile-allergens-overflow')),
        findsNothing,
      );
      if (count == 2) {
        expect(find.text('Lower sodium'), findsOneWidget);
        expect(find.text('Milk reminder'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      expect(harness.requests, 0);
    });
  }

  for (final size in [const Size(390, 844), const Size(1440, 730)]) {
    testWidgets('six choices show first two and +4 at $size', (tester) async {
      final harness = _Harness();
      final store = DeviceProfilePreferencesStore(harness.preferences);
      const saved = DeviceProfilePreferences(
        lowSugar: true,
        highFibre: true,
        vegetarian: true,
        extraPreferences: {'vegan', 'low_sodium', 'high_protein'},
        allergens: {'soy', 'tree_nuts', 'peanuts', 'eggs', 'gluten', 'milk'},
      );
      await store.write(saved);
      await harness.pump(
        tester,
        size: size,
        brightness: size.width == 390 ? Brightness.dark : Brightness.light,
      );
      final foods = find.byKey(
        const ValueKey('profile-preferences-summary-chips'),
      );
      final allergens = find.byKey(
        const ValueKey('profile-allergens-summary-chips'),
      );
      for (final summary in [foods, allergens]) {
        expect(
          find.descendant(of: summary, matching: find.byType(ActionChip)),
          findsNWidgets(3),
        );
        expect(
          find.descendant(of: summary, matching: find.text('+4')),
          findsOneWidget,
        );
      }
      expect(find.text('Low sugar'), findsOneWidget);
      expect(find.text('High fibre'), findsOneWidget);
      expect(find.text('Milk reminder'), findsOneWidget);
      expect(find.text('Gluten reminder'), findsOneWidget);
      expect(find.text('Vegetarian'), findsNothing);
      expect(find.text('Soy reminder'), findsNothing);
      final moreFoods = find.byKey(
        const ValueKey('profile-preferences-overflow'),
      );
      final chip = tester.widget<ActionChip>(moreFoods);
      expect(chip.tooltip, 'View 4 more selected preferences');
      await tester.ensureVisible(moreFoods);
      await tester.tap(moreFoods);
      await tester.pumpAndSettle();
      expect(_choice('Milk'), findsNothing);
      await tester.ensureVisible(_choice('Vegan'));
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('food-choice-vegan')))
            .getSemanticsData()
            .flagsCollection
            .isChecked,
        CheckedState.isTrue,
      );
      await tester.tap(_choice('Cancel'));
      await tester.pumpAndSettle();
      final moreAllergens = find.byKey(
        const ValueKey('profile-allergens-overflow'),
      );
      await tester.ensureVisible(moreAllergens);
      await tester.tap(moreAllergens);
      await tester.pumpAndSettle();
      expect(_choice('Low sugar'), findsNothing);
      await tester.ensureVisible(_choice('Soy'));
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('allergen-choice-soy')))
            .getSemanticsData()
            .flagsCollection
            .isChecked,
        CheckedState.isTrue,
      );
      await tester.tap(_choice('Cancel'));
      await tester.pumpAndSettle();
      final restored = await store.read();
      expect(restored.selectedPreferenceLabels, saved.selectedPreferenceLabels);
      expect(restored.allergens, saved.allergens);
      expect(tester.takeException(), isNull);
      expect(harness.requests, 0);
    });
  }

  testWidgets('desktop editors keep food and allergens in separate dialogs', (
    tester,
  ) async {
    final harness = _Harness();
    const size = Size(1440, 730);
    await harness.pump(tester, size: size);
    await harness.open(tester);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('profile-preferences-panel')))
          .width,
      560,
    );
    expect(
      find.byKey(const ValueKey('food-preferences-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('allergen-preferences-section')),
      findsNothing,
    );
    expect(_choice('Low sugar'), findsOneWidget);
    expect(_choice('High fibre'), findsOneWidget);
    expect(_choice('Vegetarian'), findsOneWidget);
    for (final label in DeviceProfilePreferences.extraPreferenceLabels.values) {
      expect(_choice(label), findsOneWidget);
    }
    expect(_choice('Milk'), findsNothing);
    expect(_choice('Save preferences'), findsOneWidget);
    _expectPinnedActions(tester, size);
    await tester.tap(_choice('Cancel'));
    await tester.pumpAndSettle();
    await harness.open(tester, allergensOnly: true);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('profile-preferences-panel')))
          .width,
      620,
    );
    expect(
      find.byKey(const ValueKey('food-preferences-section')),
      findsNothing,
    );
    expect(_choice('Low sugar'), findsNothing);
    expect(_choice('Save allergens'), findsOneWidget);
    for (final label in DeviceProfilePreferences.allergenLabels.values) {
      await tester.ensureVisible(_choice(label));
      final center = tester.getCenter(_choice(label));
      expect(center.dy, lessThan(tester.getRect(_save).top));
      expect(center.dy, greaterThan(0));
    }
    _expectPinnedActions(tester, size);
    expect(harness.requests, 0);
  });

  testWidgets(
    'food preferences stay drafts until Save and preserve allergen reminders',
    (tester) async {
      final harness = _Harness();
      final store = DeviceProfilePreferencesStore(harness.preferences);
      await store.write(
        const DeviceProfilePreferences(allergens: {'milk', 'soy'}),
      );
      await harness.pump(tester);
      await harness.open(tester);
      for (final label in [
        'Low sugar',
        'High fibre',
        'Vegetarian',
        ...DeviceProfilePreferences.extraPreferenceLabels.values,
      ]) {
        await tester.ensureVisible(_choice(label));
        await tester.tap(_choice(label));
        await tester.pump();
        _expectPinnedActions(tester, const Size(390, 700));
      }
      expect((await store.read()).allergens, {'milk', 'soy'});
      expect((await store.read()).lowSugar, false);
      await tester.tap(_save);
      await tester.pumpAndSettle();
      final restored = await store.read();
      expect(restored.lowSugar, true);
      expect(restored.highFibre, true);
      expect(restored.vegetarian, true);
      expect(
        restored.extraPreferences,
        DeviceProfilePreferences.extraPreferenceLabels.keys.toSet(),
      );
      expect(restored.selectedPreferenceLabels.length, 8);
      expect(restored.allergens, {'milk', 'soy'});
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('profile-preferences-summary-count')),
            )
            .data,
        '8 selected',
      );
      expect(find.text('Low sugar'), findsOneWidget);
      expect(find.text('High fibre'), findsOneWidget);
      expect(find.text('+6'), findsOneWidget);
      expect(find.text('Vegetarian'), findsNothing);
      for (final label
          in DeviceProfilePreferences.extraPreferenceLabels.values) {
        expect(find.text(label), findsNothing);
      }
      expect(harness.preferences.values.keys, {
        DeviceProfilePreferencesStore.key,
      });
      expect(harness.requests, 0);
      await harness.open(tester);
      final lowSugar = tester.getSemantics(
        find.byKey(const ValueKey('food-choice-low-sugar')),
      );
      expect(
        lowSugar.getSemanticsData().flagsCollection.isChecked,
        CheckedState.isTrue,
      );
      final icon = tester.widget<FeatureIcon>(
        find.descendant(
          of: find.byKey(const ValueKey('food-choice-low-sugar')),
          matching: find.byType(FeatureIcon),
        ),
      );
      expect(icon.name, 'food-low-sugar');
    },
  );

  testWidgets('Cancel discards the draft and backdrop keeps unsaved choices', (
    tester,
  ) async {
    final harness = _Harness();
    final store = DeviceProfilePreferencesStore(harness.preferences);
    await store.write(
      const DeviceProfilePreferences(
        highFibre: true,
        allergens: {'soy'},
        extraPreferences: {'vegan'},
      ),
    );
    await harness.pump(tester);
    await harness.open(tester);
    await tester.ensureVisible(_choice('Low sugar'));
    await tester.tap(_choice('Low sugar'));
    await tester.pump();
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(_dialog, findsOneWidget);
    await tester.tap(
      find.descendant(of: _dialog, matching: find.text('Cancel')),
    );
    await tester.pumpAndSettle();
    final restored = await store.read();
    expect(restored.lowSugar, false);
    expect(restored.highFibre, true);
    expect(restored.allergens, {'soy'});
    expect(restored.extraPreferences, {'vegan'});
    await harness.open(tester, allergensOnly: true);
    await tester.ensureVisible(_choice('Milk'));
    await tester.tap(_choice('Milk'));
    await tester.pump();
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(_dialog, findsOneWidget);
    await tester.tap(_choice('Cancel'));
    await tester.pumpAndSettle();
    expect((await store.read()).allergens, {'soy'});
    expect((await store.read()).highFibre, true);
    expect((await store.read()).extraPreferences, {'vegan'});
    expect(harness.requests, 0);
  });

  testWidgets(
    'all allergens stay drafts until Save and preserve food preferences',
    (tester) async {
      final harness = _Harness();
      final store = DeviceProfilePreferencesStore(harness.preferences);
      await store.write(
        const DeviceProfilePreferences(
          lowSugar: true,
          vegetarian: true,
          extraPreferences: {'high_protein', 'vegan'},
        ),
      );
      await harness.pump(tester);
      await harness.open(tester, allergensOnly: true);
      expect(_choice('Low sugar'), findsNothing);
      expect(_choice('Vegetarian'), findsNothing);
      for (final label in DeviceProfilePreferences.allergenLabels.values) {
        await tester.ensureVisible(_choice(label));
        await tester.tap(_choice(label));
        await tester.pump();
        _expectPinnedActions(tester, const Size(390, 700));
      }
      expect((await store.read()).allergens, isEmpty);
      await tester.tap(_save);
      await tester.pumpAndSettle();
      final restored = await store.read();
      expect(restored.lowSugar, true);
      expect(restored.vegetarian, true);
      expect(restored.extraPreferences, {'high_protein', 'vegan'});
      expect(
        restored.allergens,
        DeviceProfilePreferences.allergenLabels.keys.toSet(),
      );
      expect(harness.requests, 0);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('profile-allergens-summary-count')),
            )
            .data,
        '12 selected',
      );
      expect(find.text('Milk reminder'), findsOneWidget);
      expect(find.text('Gluten reminder'), findsOneWidget);
      expect(find.text('+10'), findsOneWidget);
      for (final label in DeviceProfilePreferences.allergenLabels.values.skip(
        2,
      )) {
        expect(find.text('$label reminder'), findsNothing);
      }
      await harness.open(tester, allergensOnly: true);
      await tester.ensureVisible(_choice('Milk'));
      final milk = tester.getSemantics(
        find.byKey(const ValueKey('allergen-choice-milk')),
      );
      expect(
        milk.getSemanticsData().flagsCollection.isChecked,
        CheckedState.isTrue,
      );
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets('320px large text keeps every choice reachable $brightness', (
      tester,
    ) async {
      final harness = _Harness();
      const size = Size(320, 700);
      await harness.pump(
        tester,
        size: size,
        brightness: brightness,
        textScale: 2,
      );
      await harness.open(tester);
      for (final label in [
        'Low sugar',
        'High fibre',
        'Vegetarian',
        ...DeviceProfilePreferences.extraPreferenceLabels.values,
      ]) {
        await tester.ensureVisible(_choice(label));
        await tester.tap(_choice(label));
        await tester.pump();
        _expectPinnedActions(tester, size);
      }
      await tester.tap(_save);
      await tester.pumpAndSettle();
      await harness.open(tester, allergensOnly: true);
      expect(_choice('Low sugar'), findsNothing);
      for (final label in DeviceProfilePreferences.allergenLabels.values) {
        await tester.ensureVisible(_choice(label));
        await tester.tap(_choice(label));
        await tester.pump();
        _expectPinnedActions(tester, size);
      }
      await tester.tap(_save);
      await tester.pumpAndSettle();
      final restored = await DeviceProfilePreferencesStore(harness.preferences)
          .read();
      expect(restored.lowSugar, true);
      expect(restored.highFibre, true);
      expect(restored.vegetarian, true);
      expect(restored.extraPreferences.length, 5);
      expect(restored.allergens.length, 12);
      expect(harness.requests, 0);
      expect(tester.takeException(), isNull);
    });
  }
}
