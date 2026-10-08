import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/core/capture/automatic_label_reader.dart';
import 'package:unlabel/core/capture/barcode_reader.dart';
import 'package:unlabel/core/capture/local_label_parser.dart';
import 'package:unlabel/core/capture/vision_photo.dart';
import 'package:unlabel/core/network/unlabel_repository.dart';
import 'package:unlabel/features/scanner/presentation/scan_landing_page.dart';
import 'package:zxing_lib/oned.dart';
import 'package:zxing_lib/zxing.dart';

Future<Uint8List> barcodePhoto({bool rotated = false}) async {
  final bits = EAN13Writer().encode(
    '8901764051258',
    BarcodeFormat.ean13,
    600,
    180,
  );
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawPaint(ui.Paint()..color = const ui.Color(0xffffffff));
  if (rotated) {
    canvas.translate(180, 0);
    canvas.rotate(1.5707963267948966);
  }
  for (var x = 0; x < bits.width; x++) {
    if (bits.get(x, 90)) {
      canvas.drawRect(
        ui.Rect.fromLTWH(x.toDouble(), 10, 1, 160),
        ui.Paint()..color = const ui.Color(0xff000000),
      );
    }
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(rotated ? 180 : 600, rotated ? 600 : 180);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
}

class _Repository extends UnlabelRepository {
  _Repository() : super(baseUrl: 'https://example.test');
  int cloudCalls = 0, lookups = 0;
  bool missing = false;
  @override
  Future<ProductReport> loadReport(String barcode) async {
    lookups++;
    if (missing) throw const AppFailure('not_found', 'Unknown barcode');
    return ProductReport.fromJson(
      jsonDecode(
        File('../contracts/examples/label-report-v1.historical.synthetic.json')
            .readAsStringSync(),
      ) as JsonMap,
    );
  }

  @override
  Future<List<ResearchedCandidate>> researchByBarcode(String barcode) async =>
      [];
  @override
  Future<ExtractedLabel> extractPhotos(
    Map<int, Uint8List> photos, {
    Future<void>? abortTrigger,
  }) async {
    cloudCalls++;
    throw StateError('Unexpected cloud upload');
  }
}

class _NoBarcode extends BarcodeReader {
  @override
  Future<BarcodeDetection?> read(Uint8List bytes) async => null;
}

class _PendingRepository extends _Repository {
  final started = Completer<void>();
  final reading = Completer<ExtractedLabel>();
  bool aborted = false;
  @override
  Future<ExtractedLabel> extractPhotos(
    Map<int, Uint8List> photos, {
    Future<void>? abortTrigger,
  }) {
    cloudCalls++;
    abortTrigger?.then((_) => aborted = true);
    started.complete();
    return reading.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('EAN photo and perpendicular photo decode valid identity and actual anchors', () async {
    final reader = BarcodeReader();
    addTearDown(reader.dispose);
    for (final rotated in [false, true]) {
      final decoded = await reader.read(await barcodePhoto(rotated: rotated));
      expect(decoded?.code, '8901764051258');
      expect(decoded!.points, isNotEmpty);
      expect(
        decoded.points.every(
          (p) => p.dx >= 0 && p.dx <= 1 && p.dy >= 0 && p.dy <= 1,
        ),
        isTrue,
      );
    }
    expect(validProductBarcode('8901764051259'), isFalse);
    expect(await reader.read(Uint8List.fromList([1, 2, 3])), isNull);
  });
  test('known barcode bypasses consent, AI and local OCR; unknown barcode asks for photos', () async {
    final repository = _Repository();
    final reader = AutomaticLabelReader(repository);
    addTearDown(reader.dispose);
    addTearDown(repository.close);
    var consentCalls = 0;
    Future<bool> consent() async {
      consentCalls++;
      return true;
    }

    final photo = await barcodePhoto();
    final known = await reader.read({2: photo}, allowCloud: consent);
    expect(known.report, isNotNull);
    expect(known.barcodeSlot, 2);
    expect(known.barcodePoints, isNotEmpty);
    repository.missing = true;
    final unknown = await reader.read({2: photo}, allowCloud: consent);
    expect(unknown.barcode, '8901764051258');
    expect(unknown.useful, isFalse);
    expect(repository.cloudCalls, 0);
    expect(consentCalls, 0);
  });
  test(
    'photo preparation strips metadata and stays within backend bounds',
    () async {
      final prepared = await VisionPhoto.prepare(await barcodePhoto());
      expect(prepared.bytes.length, lessThanOrEqualTo(900000));
      expect(prepared.bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(prepared.bytes, isNotEmpty);
    },
  );
  test('ambiguous multi-column local table stays unknown; explicit single basis works', () {
    final label = readLocalLabel(
      'Synthetic oats',
      'Ingredients: Oats\nNutrition per 100 g\nProtein 8 g\nEnergy 120 kcal',
    );
    expect(label.ingredients, 'Oats');
    expect(label.nutritionTables, hasLength(1));
    final ambiguous = readLocalLabel(
      '',
      'Nutrition per 100 g per 40 g\nProtein 8 g 3.2 g',
    );
    expect(ambiguous.nutritionTables, isEmpty);
  });
  test('highlights match contain letterboxing and reject unbounded boxes', () {
    expect(
      labelHighlightRect(
        const ui.Size(400, 400),
        const ui.Size(800, 400),
        const ui.Rect.fromLTWH(.25, .25, .5, .5),
      ),
      const ui.Rect.fromLTRB(100, 150, 300, 250),
    );
    expect(
      () => ExtractedRegion.fromJson({
        'slot': 'back',
        'label': 'nutrition',
        'text': 'Protein',
        'box': {'left': -1, 'top': 0, 'right': 1, 'bottom': 1},
      }),
      throwsA(isA<AppFailure>()),
    );
  });
  test(
    'stopping a read aborts its cloud wait and discards late facts',
    () async {
      final repository = _PendingRepository();
      final reader = AutomaticLabelReader(
        repository,
        barcodeReader: _NoBarcode(),
      );
      addTearDown(reader.dispose);
      addTearDown(repository.close);
      final result = expectLater(
        reader.read({0: await barcodePhoto()}, allowCloud: () async => true),
        throwsA(
          isA<AppFailure>().having((value) => value.kind, 'kind', 'cancelled'),
        ),
      );
      await repository.started.future;
      reader.cancel();
      await result.timeout(const Duration(milliseconds: 100));
      await Future<void>.delayed(Duration.zero);
      expect(repository.aborted, isTrue);
      repository.reading.complete(readLocalLabel('Late synthetic oats', ''));
      await Future<void>.delayed(Duration.zero);
      expect(repository.cloudCalls, 1);
    },
  );

  test(
    'stopping before consent completes never uploads a prepared photo',
    () async {
      final repository = _Repository();
      final reader = AutomaticLabelReader(
        repository,
        barcodeReader: _NoBarcode(),
      );
      addTearDown(reader.dispose);
      addTearDown(repository.close);
      final consent = Completer<bool>();
      final started = Completer<void>();
      final result = expectLater(
        reader.read(
          {0: await barcodePhoto()},
          allowCloud: () {
            started.complete();
            return consent.future;
          },
        ),
        throwsA(
          isA<AppFailure>().having((value) => value.kind, 'kind', 'cancelled'),
        ),
      );
      await started.future;
      reader.cancel();
      await result.timeout(const Duration(milliseconds: 100));
      consent.complete(true);
      await Future<void>.delayed(Duration.zero);
      expect(repository.cloudCalls, 0);
    },
  );
}
