import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../models/app_failure.dart';
import 'photo_decode.dart';

/// The centred source rectangle shown by an aspect-preserving cover preview.
/// Still and preview streams can have different aspect ratios. First restrict
/// the still to the preview stream, then apply the viewport's cover crop.
ui.Rect cameraVisibleRect(
  ui.Size source,
  ui.Size viewport, {
  required double previewAspectRatio,
}) {
  if (!source.isFinite ||
      source.isEmpty ||
      !viewport.isFinite ||
      viewport.isEmpty ||
      !previewAspectRatio.isFinite ||
      previewAspectRatio <= 0) {
    throw ArgumentError('Camera dimensions must be positive and finite.');
  }
  ui.Rect cover(ui.Rect input, double ratio) {
    final width = math.min(input.width, input.height * ratio);
    final height = math.min(input.height, input.width / ratio);
    return ui.Rect.fromCenter(
      center: input.center,
      width: width,
      height: height,
    );
  }

  return cover(
    cover(ui.Offset.zero & source, previewAspectRatio),
    viewport.aspectRatio,
  );
}

/// Crops upright decoded pixels, without stretching, and strips photo metadata.
/// Gallery selections use the whole image and do not pass through this crop.
Future<Uint8List> cropCameraPhoto(
  Uint8List bytes,
  ui.Size viewport, {
  required double previewAspectRatio,
  bool unmirror = false,
}) async {
  final decoded = await decodePhoto(bytes, maxEdge: 2400);
  final source = decoded.image;
  try {
    final rect = cameraVisibleRect(
      ui.Size(source.width.toDouble(), source.height.toDouble()),
      viewport,
      previewAspectRatio: previewAspectRatio,
    );
    final scale = math.min(1.0, 1600 / math.max(rect.width, rect.height));
    final width = math.max(1, (rect.width * scale).round());
    final height = math.max(1, (rect.height * scale).round());
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    if (unmirror) {
      canvas.translate(width.toDouble(), 0);
      canvas.scale(-1, 1);
    }
    canvas.drawImageRect(
      source,
      rect,
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
    final picture = recorder.endRecording();
    try {
      final cropped = await picture.toImage(width, height);
      try {
        final png = await cropped.toByteData(format: ui.ImageByteFormat.png);
        if (png == null || png.lengthInBytes > 12 * 1024 * 1024) {
          throw const AppFailure(
            'invalid_photo',
            'Retake a closer photo of the label.',
          );
        }
        return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
      } finally {
        cropped.dispose();
      }
    } finally {
      picture.dispose();
    }
  } finally {
    source.dispose();
  }
}
