import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/core/capture/photo_decode.dart';
import 'package:unlabel/core/models/app_failure.dart';

Uint8List _pngHeader(int width, int height) {
  final bytes = Uint8List(24)
    ..setRange(0, 8, [137, 80, 78, 71, 13, 10, 26, 10])
    ..setRange(12, 16, 'IHDR'.codeUnits);
  final data = ByteData.sublistView(bytes)
    ..setUint32(16, width)
    ..setUint32(20, height);
  return data.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('photo headers enforce bounds before decode and fail closed on truncated formats', () {
    expect(photoHeaderSize(_pngHeader(1200, 800)), const ui.Size(1200, 800));
    for (final bytes in [
      _pngHeader(0, 100),
      _pngHeader(100000, 100000),
      Uint8List(30),
      Uint8List.fromList([255, 216, ...List.filled(22, 255)]),
    ]) {
      expect(() => photoHeaderSize(bytes), throwsA(isA<AppFailure>()));
    }
  });
  test(
    'WebP dimension modes remain bounded rather than using descriptor getters',
    () {
      final bytes = Uint8List(30)
        ..setRange(0, 4, 'RIFF'.codeUnits)
        ..setRange(8, 12, 'WEBP'.codeUnits)
        ..setRange(12, 16, 'VP8X'.codeUnits);
      bytes[24] = 99;
      bytes[27] = 49;
      expect(photoHeaderSize(bytes), const ui.Size(100, 50));
      bytes[25] = 255;
      bytes[26] = 255;
      expect(() => photoHeaderSize(bytes), throwsA(isA<AppFailure>()));
    },
  );
  test(
    'decoder preserves upright geometry and bounds returned pixels',
    () async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder)
        ..drawPaint(ui.Paint()..color = const ui.Color(0xffffffff));
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, 10, 20),
        ui.Paint()..color = const ui.Color(0xff000000),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(400, 200);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      final decoded = await decodePhoto(
        png!.buffer.asUint8List(),
        maxEdge: 100,
      );
      expect(decoded.originalSize, const ui.Size(400, 200));
      expect(decoded.image.width, 100);
      expect(decoded.image.height, 50);
      decoded.image.dispose();
    },
  );
}
