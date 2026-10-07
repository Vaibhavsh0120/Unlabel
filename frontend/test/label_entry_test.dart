import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/core/capture/local_ocr.dart';
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

final _photo = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aB3sAAAAASUVORK5CYII=',
);

class _Reader extends LocalOcrReader {
  _Reader(this.results);
  final List<Future<String>> results;
  int calls = 0, cancels = 0;
  @override
  Future<String> recognize(
    Uint8List bytes, {
    String language = 'en',
    void Function(double?)? onProgress,
  }) => results[calls++];
  @override
  void cancel() => cancels++;
}

const _confirmations = [
  'I checked the identity and claims on the package front',
  'I checked and corrected the back-label facts I entered',
  'The front, back and any barcode belong to this same package',
];

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
    'OCR suggestions require review, preserve entries and never submit photos or raw text',
    (tester) async {
      final repository = DraftRepository();
      addTearDown(repository.close);
      final reader = _Reader([
        Future.value('Synthetic OCR oats\nPrivate front reference'),
        Future.value(
          'Ingredients: OCR oats\nContains: milk\nMay contain: peanuts\nNutrition\nPrivate back reference\nSugars 0 g',
        ),
      ]);
      addTearDown(reader.dispose);
      var reports = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: LabelEntryPage(
            repository: repository,
            onReport: (_) => reports++,
            capturePhotos: {0: _photo, 1: _photo},
            ocrReader: reader,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(reader.calls, 2);
      expect(
        tester
            .widget<TextField>(field('Printed product name'))
            .controller!
            .text,
        isEmpty,
      );
      expect(repository.submissions, isEmpty);
      await fill(tester, 'Printed product name', 'Manually checked name');
      await click(
        tester,
        find.ancestor(
          of: find.text('Ingredients capture'),
          matching: find.byType(DropdownButtonFormField<String>),
        ),
      );
      await tester.tap(find.text('Printed text present').last);
      await tester.pumpAndSettle();
      await fill(tester, 'Whole Ingredients text', 'Manually checked oats');
      for (final label in _confirmations) {
        await click(tester, find.widgetWithText(CheckboxListTile, label));
      }
      await click(tester, find.text('Use text suggestions'));
      expect(
        tester
            .widget<TextField>(field('Printed product name'))
            .controller!
            .text,
        'Manually checked name',
      );
      expect(
        tester
            .widget<TextField>(field('Whole Ingredients text'))
            .controller!
            .text,
        'Manually checked oats',
      );
      expect(
        tester
            .widget<TextField>(field('Whole Contains statement text'))
            .controller!
            .text,
        'milk',
      );
      expect(
        tester
            .widget<TextField>(field('Whole May contain statement text'))
            .controller!
            .text,
        'peanuts',
      );
      for (final label in _confirmations) {
        expect(
          tester
              .widget<CheckboxListTile>(
                find.widgetWithText(CheckboxListTile, label),
              )
              .value,
          isFalse,
        );
      }
      expect(find.text('Protein value'), findsNothing);
      await click(tester, find.text('Check confirmed label'));
      expect(repository.submissions, isEmpty);
      for (final label in _confirmations) {
        await click(tester, find.widgetWithText(CheckboxListTile, label));
      }
      await click(tester, find.text('Check confirmed label'));
      expect(reports, 1);
      final observation =
          repository.submissions.single.toPayload()['observation'] as JsonMap;
      expect(observation['capture_method'], 'ocr_corrected');
      expect(observation['identity']['name'], 'Manually checked name');
      expect(observation['ingredients']['text'], 'Manually checked oats');
      expect(observation['contains']['text'], 'milk');
      expect(observation['may_contain']['text'], 'peanuts');
      expect(observation['rows'], isEmpty);
      expect(observation['contains']['completeness'], 'partial');
      expect(
        jsonEncode(observation),
        isNot(contains('Private front reference')),
      );
      expect(
        jsonEncode(observation),
        isNot(contains('Private back reference')),
      );
      expect(
        observation.keys.any(
          (key) =>
              key.contains('photo') ||
              key.contains('image') ||
              key.contains('ocr'),
        ),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'stopping OCR discards its late response and keeps manual entry available',
    (tester) async {
      final repository = DraftRepository();
      addTearDown(repository.close);
      final pending = Completer<String>();
      final reader = _Reader([pending.future]);
      addTearDown(reader.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: LabelEntryPage(
            repository: repository,
            onReport: (_) {},
            capturePhotos: {0: _photo},
            ocrReader: reader,
          ),
        ),
      );
      await tester.pump();
      expect(reader.calls, 1);
      await Scrollable.ensureVisible(
        tester.element(find.text('Stop reading')),
        alignment: 0.5,
      );
      await tester.pump();
      await tester.tap(find.text('Stop reading'));
      await tester.pumpAndSettle();
      expect(reader.cancels, 1);
      pending.complete('Late private text');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ocr-front-text')), findsNothing);
      expect(find.text('Read text on this device'), findsOneWidget);
      await fill(tester, 'Printed product name', 'Manual label');
      expect(
        tester
            .widget<TextField>(field('Printed product name'))
            .controller!
            .text,
        'Manual label',
      );
      expect(repository.submissions, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
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
