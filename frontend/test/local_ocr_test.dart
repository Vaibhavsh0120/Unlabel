import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/core/capture/label_text_suggestions.dart';
import 'package:unlabel/core/capture/local_ocr.dart';
import 'package:unlabel/core/models/label_draft.dart';

final _photo = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aB3sAAAAASUVORK5CYII=',
);

class _Engine implements LocalOcrEngine {
  final started = Completer<void>();
  final text = Completer<String>();
  int calls = 0, cancels = 0;
  void Function(double?)? progress;
  Uint8List? image;
  @override
  Future<String> recognize(
    Uint8List bytes,
    String language,
    void Function(double?) onProgress,
  ) {
    calls++;
    image = bytes;
    progress = onProgress;
    if (!started.isCompleted) started.complete();
    return text.future;
  }

  @override
  void cancel() => cancels++;
  @override
  void dispose() => cancel();
}

Matcher get _failure => isA<LocalOcrFailure>();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'local OCR validates an image and keeps the recognized text session-only',
    () async {
      final engine = _Engine();
      final reader = LocalOcrReader(engine: engine);
      addTearDown(reader.dispose);
      final read = reader.recognize(_photo);
      await engine.started.future;
      engine.text.complete('  Ingredients: oats\r\nContains: milk\u0000  ');
      expect(await read, 'Ingredients: oats\nContains: milk');
      expect(engine.image, _photo);
    },
  );

  test('invalid or oversized images never reach the OCR engine', () async {
    final engine = _Engine();
    final reader = LocalOcrReader(engine: engine);
    addTearDown(reader.dispose);
    for (final bytes in [
      Uint8List(0),
      Uint8List(LocalOcrReader.maxBytes + 1),
      Uint8List.fromList([1, 2, 3]),
    ]) {
      await expectLater(reader.recognize(bytes), throwsA(_failure));
    }
    expect(engine.calls, 0);
  });

  test('cancel suppresses both late output and progress', () async {
    final engine = _Engine();
    final reader = LocalOcrReader(engine: engine);
    addTearDown(reader.dispose);
    var progressCalls = 0;
    final read = reader.recognize(_photo, onProgress: (_) => progressCalls++);
    final rejected = expectLater(read, throwsA(_failure));
    await engine.started.future;
    reader.cancel();
    engine.progress!(0.75);
    engine.text.complete('Late private text');
    await rejected;
    expect(progressCalls, 0);
    expect(engine.cancels, 1);
  });

  test('OCR timeout cancels work and leaves a retry/manual path', () async {
    final engine = _Engine();
    final reader = LocalOcrReader(
      engine: engine,
      timeout: const Duration(milliseconds: 5),
    );
    addTearDown(reader.dispose);
    await expectLater(reader.recognize(_photo), throwsA(_failure));
    expect(engine.cancels, 1);
    engine.text.complete('Late text');
  });

  test(
    'oversized recognized text is rejected instead of silently truncated',
    () async {
      final engine = _Engine();
      final reader = LocalOcrReader(engine: engine);
      addTearDown(reader.dispose);
      engine.text.complete('A' * (LocalOcrReader.maxText + 1));
      await expectLater(reader.recognize(_photo), throwsA(_failure));
    },
  );

  test(
    'section suggestions preserve wording and separate allergen statements',
    () {
      final suggestion = LabelTextSuggestions.fromText(
        'Synthetic oats\nBrand',
        'Ingredients: oats, milk\nContains: milk\nMay contain: peanuts\nNutrition\nSugars 0 g',
      );
      expect(suggestion.name, 'Synthetic oats');
      expect(suggestion.ingredients, 'oats, milk');
      expect(suggestion.contains, 'milk');
      expect(suggestion.mayContain, 'peanuts');
    },
  );

  test('ambiguous repeated sections and missing labels stay unknown', () {
    final suggestion = LabelTextSuggestions.fromText(
      '',
      'Ingredients: oats\nNutrition\nIngredients: rice\nSugars 0 g',
    );
    expect(suggestion.name, isNull);
    expect(suggestion.ingredients, isNull);
    expect(suggestion.contains, isNull);
    expect(suggestion.mayContain, isNull);
  });

  test(
    'corrected OCR report payload contains only confirmed structured facts',
    () {
      final draft = LabelDraft(
        name: 'Synthetic oats',
        ingredients: const DraftSection(status: 'present', text: 'oats, milk'),
        frontConfirmed: true,
        backConfirmed: true,
        samePackageConfirmed: true,
        captureMethod: 'ocr_corrected',
      );
      final observation =
          draft.toPayload()['observation'] as Map<String, dynamic>;
      expect(observation['capture_method'], 'ocr_corrected');
      expect(observation['ingredients']['text'], 'oats, milk');
      expect(observation['provider_references'], isEmpty);
      expect(
        observation.keys.where(
          (key) =>
              key.contains('photo') ||
              key.contains('ocr') ||
              key.contains('image'),
        ),
        isEmpty,
      );
      expect(observation['rows'], isEmpty);
      expect(
        () => LabelDraft(
          name: 'Synthetic oats',
          ingredients: const DraftSection(status: 'present', text: 'oats'),
          captureMethod: 'ocr_corrected',
        ).toPayload(),
        throwsA(isA<Exception>()),
      );
    },
  );
}
