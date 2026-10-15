import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/core/capture/camera_framing.dart';
import 'package:unlabel/core/capture/photo_decode.dart';

Future<Uint8List> _markers() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  for (final (left, color) in [
    (0.0, 0xffff0000),
    (100.0, 0xff00ff00),
    (200.0, 0xff0000ff),
    (300.0, 0xffffff00),
  ]) {
    canvas.drawRect(
      ui.Rect.fromLTWH(left, 0, 100, 200),
      ui.Paint()..color = ui.Color(color),
    );
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(400, 200);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return png!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('centre crop matches portrait, landscape and square cover previews', () {
    const source = ui.Size(400, 300);
    expect(
      cameraVisibleRect(
        source,
        const ui.Size(300, 300),
        previewAspectRatio: 4 / 3,
      ),
      const ui.Rect.fromLTWH(50, 0, 300, 300),
    );
    expect(
      cameraVisibleRect(
        source,
        const ui.Size(400, 200),
        previewAspectRatio: 4 / 3,
      ),
      const ui.Rect.fromLTWH(0, 50, 400, 200),
    );
    expect(
      cameraVisibleRect(
        source,
        const ui.Size(100, 200),
        previewAspectRatio: 4 / 3,
      ),
      const ui.Rect.fromLTWH(125, 0, 150, 300),
    );
  });

  test(
    'still crop retains the preview stream crop before applying viewport',
    () {
      final rect = cameraVisibleRect(
        const ui.Size(4000, 3000),
        const ui.Size(300, 400),
        previewAspectRatio: 16 / 9,
      );
      expect(rect, const ui.Rect.fromLTWH(1156.25, 375, 1687.5, 2250));
      for (final viewport in [
        ui.Size.zero,
        const ui.Size(double.infinity, 1),
      ]) {
        expect(
          () => cameraVisibleRect(
            const ui.Size(400, 300),
            viewport,
            previewAspectRatio: 4 / 3,
          ),
          throwsArgumentError,
        );
      }
    },
  );

  test(
    'capture keeps visible centre markers and removes off-screen edges',
    () async {
      final cropped = await cropCameraPhoto(
        await _markers(),
        const ui.Size(200, 200),
        previewAspectRatio: 2,
      );
      final decoded = await decodePhoto(cropped);
      expect(decoded.originalSize, const ui.Size(200, 200));
      final pixels = (await decoded.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      expect(pixels.getUint32((100 * 200 + 20) * 4), 0x00ff00ff);
      expect(pixels.getUint32((100 * 200 + 180) * 4), 0x0000ffff);
      decoded.image.dispose();
    },
  );

  test(
    'web front capture is unmirrored once without changing framing',
    () async {
      final cropped = await cropCameraPhoto(
        await _markers(),
        const ui.Size(200, 200),
        previewAspectRatio: 2,
        unmirror: true,
      );
      final decoded = await decodePhoto(cropped);
      final pixels = (await decoded.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      expect(pixels.getUint32((100 * 200 + 20) * 4), 0x0000ffff);
      expect(pixels.getUint32((100 * 200 + 180) * 4), 0x00ff00ff);
      decoded.image.dispose();
    },
  );
}
