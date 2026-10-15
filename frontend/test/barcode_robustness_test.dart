import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/core/capture/barcode_reader.dart';
import 'package:zxing_lib/oned.dart';

const _code = '8901764051258';

Future<({Uint8List bytes, ui.Rect bounds})> _fixture({
  bool inverted = false,
  bool offCenter = false,
  bool lowContrast = false,
  bool invalidChecksum = false,
  int turns = 0,
}) async {
  // Synthetic bars are generated at runtime; no photographed product data is stored.
  final modules = EAN13Writer().encodeContent(_code);
  if (invalidChecksum) {
    // Replace the final digit's valid EAN R-pattern 8 with R-pattern 9.
    // All guards and digit widths remain valid, but the checksum must fail.
    final wrongDigit = '1110100';
    for (var i = 0; i < 7; i++) {
      modules[85 + i] = wrongDigit[i] == '1';
    }
  }
  const width = 600, height = 900;
  final top = offCenter ? 24.0 : 400.0;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final dark = lowContrast ? 100 : 0;
  final light = lowContrast ? 155 : 255;
  ui.Color grey(int value) => ui.Color.fromARGB(255, value, value, value);
  canvas.drawPaint(ui.Paint()..color = grey(inverted ? dark : light));
  switch (turns) {
    case 1:
      canvas.translate(height.toDouble(), 0);
    case 2:
      canvas.translate(width.toDouble(), height.toDouble());
    case 3:
      canvas.translate(0, width.toDouble());
  }
  canvas.rotate(turns * math.pi / 2);
  for (var x = 0; x < modules.length; x++) {
    if (modules[x]) {
      canvas.drawRect(
        ui.Rect.fromLTWH(110 + x * 4.0, top, 4, 80),
        ui.Paint()..color = grey(inverted ? light : dark),
      );
    }
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    turns.isEven ? width : height,
    turns.isEven ? height : width,
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  final rect = ui.Rect.fromLTWH(110, top, 380, 80);
  final transformed = switch (turns) {
    1 => ui.Rect.fromLTRB(
      height - rect.bottom,
      rect.left,
      height - rect.top,
      rect.right,
    ),
    2 => ui.Rect.fromLTRB(
      width - rect.right,
      height - rect.bottom,
      width - rect.left,
      height - rect.top,
    ),
    3 => ui.Rect.fromLTRB(
      rect.top,
      width - rect.right,
      rect.bottom,
      width - rect.left,
    ),
    _ => rect,
  };
  return (
    bytes: bytes!.buffer.asUint8List(),
    bounds: ui.Rect.fromLTRB(
      transformed.left / (turns.isEven ? width : height),
      transformed.top / (turns.isEven ? height : width),
      transformed.right / (turns.isEven ? width : height),
      transformed.bottom / (turns.isEven ? height : width),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final turns in [0, 1, 2, 3]) {
    test(
      'off-center barcode at quarter-turn $turns keeps correct identity and anchors',
      () async {
        final reader = BarcodeReader();
        addTearDown(reader.dispose);
        final photo = await _fixture(offCenter: true, turns: turns);
        final result = await reader.read(photo.bytes);
        expect(result?.code, _code);
        expect(result!.points.length, greaterThanOrEqualTo(2));
        expect(result.points.every(photo.bounds.inflate(.01).contains), isTrue);
      },
    );
  }

  for (final lowContrast in [false, true]) {
    test(
      'inverted off-center barcode supports low contrast=$lowContrast',
      () async {
        final reader = BarcodeReader();
        addTearDown(reader.dispose);
        final photo = await _fixture(
          inverted: true,
          offCenter: true,
          lowContrast: lowContrast,
        );
        final result = await reader.read(photo.bytes);
        expect(result?.code, _code);
        expect(
          result!.points.every(photo.bounds.inflate(.01).contains),
          isTrue,
        );
      },
    );
  }

  test(
    'invalid checksum is rejected in ordinary and inverted wider scans',
    () async {
      final reader = BarcodeReader();
      addTearDown(reader.dispose);
      for (final inverted in [false, true]) {
        final photo = await _fixture(
          invalidChecksum: true,
          inverted: inverted,
          offCenter: true,
        );
        expect(await reader.read(photo.bytes), isNull);
      }
    },
  );

  test('cancel and disposal discard a pending decoded identity', () async {
    final reader = BarcodeReader();
    final photo = await _fixture();
    final reading = reader.read(photo.bytes);
    reader.cancel();
    expect(await reading, isNull);
    reader.dispose();
    expect(await reader.read(photo.bytes), isNull);
  });
}
