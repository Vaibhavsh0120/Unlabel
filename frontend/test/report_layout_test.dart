import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/app/unlabel_theme.dart';
import 'package:unlabel/core/models/product_report.dart';
import 'package:unlabel/core/storage/local_store.dart';
import 'package:unlabel/features/scanner/presentation/product_info_page.dart';
import 'package:unlabel/features/scanner/presentation/product_results_layout.dart';

class _MemoryPreferences implements PreferencesAdapter {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}

ProductReport _report({bool historical = false}) => ProductReport.fromJson(
  jsonDecode(
    File(
      '../contracts/examples/label-report-v1.${historical ? 'historical' : 'current'}.synthetic.json',
    ).readAsStringSync(),
  ) as JsonMap,
);

Widget _app(ProductReport report, Brightness brightness) => MaterialApp(
  theme: UnlabelTheme.forBrightness(brightness),
  home: ProductInfoPage.report(
    report: report,
    store: LocalStore(preferences: _MemoryPreferences()),
    onChanged: () {},
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final family in ['Nunito', 'Quicksand']) {
      final loader = FontLoader(family)
        ..addFont(rootBundle.load('assets/brand/fonts/$family-Variable.ttf'));
      await loader.load();
    }
  });
  testWidgets(
    'reference evidence and nutrient grids adapt without hiding facts',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final width in [390.0, 1440.0]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpWidget(_app(_report(), Brightness.dark));
        await tester.pumpAndSettle();
        final nutrition = tester.getRect(find.text('Nutrition facts'));
        final claims = tester.getRect(find.text('Claim evidence'));
        final ingredients = tester.getRect(find.text('Ingredient declaration'));
        expect(nutrition.top, closeTo(claims.top, 1));
        expect(
          ingredients.top,
          width == 390 ? greaterThan(nutrition.top) : closeTo(nutrition.top, 1),
        );
        final first = tester.getRect(
          find.byKey(const Key('report-nutrient-0')),
        );
        final third = tester.getRect(
          find.byKey(const Key('report-nutrient-2')),
        );
        final fourth = tester.getRect(
          find.byKey(const Key('report-nutrient-3')),
        );
        expect(first.top, closeTo(third.top, 1));
        if (width == 390) {
          expect(
            tester.getSize(find.text('Carbohydrates')).height,
            lessThanOrEqualTo(18),
            reason: 'The complete nutrient label fits without an orphan letter.',
          );
          expect(
            tester
                .getSize(find.byKey(const Key('report-evidence-summary')))
                .height,
            lessThanOrEqualTo(160),
            reason: 'The phone overview stays compact at default text size.',
          );
        }
        expect(
          fourth.top,
          width == 390 ? greaterThan(first.top) : closeTo(first.top, 1),
        );
        expect(find.text('Total sugars'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets(
    'allergen tab and missing facts disclosure retain their details',
    (tester) async {
      final report = _report();
      await tester.pumpWidget(_app(report, Brightness.light));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Allergens'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allergens'));
      await tester.pumpAndSettle();
      expect(find.text('Contains'), findsOneWidget);
      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('May contain'), findsOneWidget);
      final unknownItems = {...report.missingInputs, ...report.warnings};
      final showMore = find.text('+${unknownItems.length - 4} more');
      await tester.ensureVisible(showMore);
      await tester.pumpAndSettle();
      await tester.tap(showMore);
      await tester.pumpAndSettle();
      expect(find.text('Show less'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('desktop results navigation invokes each app destination', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final visits = <String>[];
    final nav = ResultsNavigation(
      home: () => visits.add('home'),
      scan: () => visits.add('scan'),
      history: () => visits.add('history'),
      learn: () => visits.add('learn'),
      products: () => visits.add('products'),
      profile: () => visits.add('profile'),
      notifications: () => visits.add('notifications'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: ResultsAppBar(title: 'Scan Results', navigation: nav),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final title in ['Unlabel', 'Scan', 'History', 'Learn', 'Products']) {
      await tester.tap(find.text(title));
    }
    await tester.tap(find.text('Search product, ingredient or claim…'));
    await tester.tap(find.byTooltip('Profile'));
    await tester.tap(find.byTooltip('Notifications'));
    expect(visits, [
      'home',
      'scan',
      'history',
      'learn',
      'products',
      'products',
      'profile',
      'notifications',
    ]);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'reference report sections preserve facts and disclose all evidence',
    (tester) async {
      final report = _report();
      await tester.pumpWidget(_app(report, Brightness.light));
      await tester.pumpAndSettle();
      expect(find.text('Product info'), findsOneWidget);
      expect(find.text(report.name), findsOneWidget);
      expect(find.byKey(const Key('report-product-card')), findsOneWidget);
      expect(find.byKey(const Key('report-evidence-summary')), findsOneWidget);
      expect(find.text('Contradicted'), findsOneWidget);
      expect(find.text(report.claims.single.reason), findsOneWidget);
      expect(find.text('30 g'), findsOneWidget);
      expect(find.text('About 3 sugar cubes'), findsOneWidget);
      expect(
        find.textContaining('12 g total sugars · Per serving (40 g)'),
        findsOneWidget,
      );
      expect(find.textContaining('/100'), findsNothing);
      expect(find.text('0 g'), findsNothing);
      expect(
        find
            .byType(Image)
            .evaluate()
            .every((element) => (element.widget as Image).image is AssetImage),
        isTrue,
      );

      final evidence = find.byKey(const Key('report-nutrient-evidence'));
      await tester.ensureVisible(evidence);
      await tester.pumpAndSettle();
      await tester.tap(find.text('All nutrients, evidence & sources'));
      await tester.pumpAndSettle();
      for (final nutrient in report.nutrients) {
        expect(find.text(nutrient.basisLabel), findsWidgets);
      }
      expect(find.text('Fibre'), findsOneWidget);
      expect(find.text('Added sugars'), findsOneWidget);
      expect(
        find.text('Observed 2026-10-07'),
        findsNWidgets(report.nutrients.length),
      );
      expect(find.text('Source references'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('report cards grow and remain reachable at supported widths', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.devicePixelRatio = 1;
    for (final brightness in Brightness.values) {
      for (final width in [320.0, 390.0, 768.0, 1440.0]) {
        for (final scale in width == 320 ? [1.0, 2.0] : [1.0]) {
          tester.view.physicalSize = Size(width, 844);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await tester.pumpWidget(
            _app(_report(historical: width == 768), brightness),
          );
          await tester.pumpAndSettle();
          final productRect = tester.getRect(
            find.byKey(const Key('report-product-card')),
          );
          expect(productRect.left, greaterThanOrEqualTo(0));
          expect(productRect.right, lessThanOrEqualTo(width));
          for (final key in [
            'report-evidence-summary',
            'report-nutrition-snapshot',
          ]) {
            final target = find.byKey(Key(key));
            await tester.ensureVisible(target);
            await tester.pumpAndSettle();
            final rect = tester.getRect(target);
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(width));
            expect(
              tester.takeException(),
              isNull,
              reason: '$brightness, width $width, text scale $scale',
            );
          }
          for (final section in [
            'Ingredients & allergens',
            'Source references',
          ]) {
            await tester.ensureVisible(find.text(section));
            await tester.pumpAndSettle();
            expect(find.text(section).hitTestable(), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }
      }
    }
  });
}
