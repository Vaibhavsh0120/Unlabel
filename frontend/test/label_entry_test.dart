import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/core/network/unlabel_repository.dart';
import 'package:unlabel/features/scanner/presentation/label_entry_page.dart';

class DraftRepository extends UnlabelRepository {
  DraftRepository() : super(baseUrl: 'https://example.test');
  final submissions = <LabelDraft>[];
  bool failNext = false;
  @override
  Future<ProductReport> checkLabel(LabelDraft draft) async {
    submissions.add(draft);
    draft.toPayload();
    if (failNext) {
      failNext = false;
      throw const AppFailure('timeout', 'Synthetic timeout; entries are kept.');
    }
    return ProductReport.fromJson(
      jsonDecode(
        File('../contracts/examples/label-report-v1.current.synthetic.json')
            .readAsStringSync(),
      ) as JsonMap,
    );
  }
}

Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> fill(WidgetTester tester, String label, String value) async {
  await tester.ensureVisible(field(label));
  await tester.pumpAndSettle();
  await tester.enterText(field(label), value);
  await tester.pumpAndSettle();
}

Future<void> click(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'manual form at320px2x has no overflow and all confirmations start empty',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = DraftRepository();
      addTearDown(repository.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: LabelEntryPage(repository: repository, onReport: (_) {}),
        ),
      );
      expect(tester.takeException(), isNull);
      await click(tester, find.text('Add printed nutrient row'));
      expect(find.text('Printed basis amount'), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final box in tester.widgetList<CheckboxListTile>(
        find.byType(CheckboxListTile),
      )) {
        expect(box.value, isFalse);
      }
      await click(tester, find.text('Check confirmed label'));
      expect(repository.submissions, isEmpty);
      expect(find.text('Confirmation is required.'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'confirmed label retries keepUUID untilanedit and submitexactmanualfacts',
    (tester) async {
      final repository = DraftRepository()..failNext = true;
      addTearDown(repository.close);
      var reports = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: LabelEntryPage(
            repository: repository,
            onReport: (_) => reports++,
          ),
        ),
      );
      await fill(tester, 'Printed product name', 'Synthetic oats');
      await click(
        tester,
        find.ancestor(
          of: find.text('Ingredients capture'),
          matching: find.byType(DropdownButtonFormField<String>),
        ),
      );
      await tester.tap(find.text('Printed text present').last);
      await tester.pumpAndSettle();
      await fill(tester, 'Whole Ingredients text', 'Synthetic oats, milk');
      for (final label in [
        'I checked the identity and claims on the package front',
        'I checked and corrected the back-label facts I entered',
        'The front, back and any barcode belong to this same package',
      ]) {
        await click(tester, find.widgetWithText(CheckboxListTile, label));
      }
      await click(tester, find.text('Check confirmed label'));
      expect(repository.submissions, hasLength(1));
      expect(reports, 0);
      await click(tester, find.text('Check confirmed label'));
      expect(repository.submissions, hasLength(2));
      expect(reports, 1);
      expect(
        repository.submissions[0].submissionId,
        repository.submissions[1].submissionId,
      );
      expect(
        repository.submissions.last
            .toPayload()['observation']['provider_references'],
        isEmpty,
      );
      expect(
        repository.submissions.last
            .toPayload()['observation']['ingredients']['text'],
        'Synthetic oats, milk',
      );
      await fill(tester, 'Printed product name', 'Synthetic edited oats');
      await click(tester, find.text('Check confirmed label'));
      expect(repository.submissions, hasLength(2));
      expect(
        tester
            .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
            .where((widget) => widget.value == true),
        isEmpty,
      );
      for (final label in [
        'I checked the identity and claims on the package front',
        'I checked and corrected the back-label facts I entered',
        'The front, back and any barcode belong to this same package',
      ]) {
        await click(tester, find.widgetWithText(CheckboxListTile, label));
      }
      await click(tester, find.text('Check confirmed label'));
      expect(repository.submissions, hasLength(3));
      expect(
        repository.submissions.last.submissionId,
        isNot(repository.submissions.first.submissionId),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
