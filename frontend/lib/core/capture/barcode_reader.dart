import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:zxing_lib/common.dart';
import 'package:zxing_lib/zxing.dart';

import '../models/extracted_label.dart';
import 'photo_decode.dart';

class BarcodeDetection {
  const BarcodeDetection(this.code, this.points);
  final String code;

  /// Actual decoder scan-line anchors, normalized in the upright original photo.
  /// These points do not claim to bound the entire printed barcode.
  final List<ui.Offset> points;
}

class BarcodeReader {
  int _generation = 0;
  bool _disposed = false;
  Future<BarcodeDetection?> read(Uint8List bytes) async {
    if (_disposed || bytes.isEmpty || bytes.length > 12 * 1024 * 1024) {
      return null;
    }
    final generation = ++_generation;
    ui.Image? image;
    try {
      image = (await decodePhoto(bytes, maxEdge: 1400)).image;
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (rgba == null || _disposed || generation != _generation) return null;
      final decoded = await compute(
        _decode,
        _BarcodePixels(
          image.width,
          image.height,
          rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes),
        ),
      );
      if (_disposed || generation != _generation || decoded == null) {
        return null;
      }
      return BarcodeDetection(decoded.code, List.unmodifiable(decoded.points));
    } catch (_) {
      return null;
    } finally {
      image?.dispose();
    }
  }

  void cancel() => _generation++;
  void dispose() {
    _disposed = true;
    cancel();
  }
}

class _BarcodePixels {
  const _BarcodePixels(this.width, this.height, this.rgba);
  final int width, height;
  final Uint8List rgba;
}

BarcodeDetection? _decode(_BarcodePixels pixels) {
  final luminance = Uint8List(pixels.width * pixels.height);
  for (var i = 0; i < luminance.length; i++) {
    final offset = i * 4;
    final alpha = pixels.rgba[offset + 3];
    final value =
        (pixels.rgba[offset] +
            2 * pixels.rgba[offset + 1] +
            pixels.rgba[offset + 2]) ~/
        4;
    luminance[i] = (value * alpha + 255 * (255 - alpha)) ~/ 255;
  }
  final hints = const DecodeHint(
    possibleFormats: [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
  );
  for (var rotated = 0; rotated < 2; rotated++) {
    final width = rotated == 0 ? pixels.width : pixels.height;
    final height = rotated == 0 ? pixels.height : pixels.width;
    var bytes = luminance;
    if (rotated == 1) {
      bytes = Uint8List(luminance.length);
      for (var y = 0; y < pixels.height; y++) {
        for (var x = 0; x < pixels.width; x++) {
          bytes[x * pixels.height + pixels.height - 1 - y] =
              luminance[y * pixels.width + x];
        }
      }
    }
    try {
      final result = MultiFormatReader().decode(
        BinaryBitmap(
          HybridBinarizer(RGBLuminanceSource.orig(width, height, bytes)),
        ),
        hints,
      );
      final code = result.barcodeFormat == BarcodeFormat.upcE
          ? _expandUpce(result.text)
          : result.text;
      if (!validProductBarcode(code)) continue;
      final points = <ui.Offset>[];
      for (final point in result.resultPoints ?? <ResultPoint?>[]) {
        if (point == null) continue;
        final x = rotated == 0 ? point.x : point.y;
        final y = rotated == 0 ? point.y : pixels.height - 1 - point.x;
        points.add(
          ui.Offset(
            (x / pixels.width).clamp(0, 1),
            (y / pixels.height).clamp(0, 1),
          ),
        );
      }
      return BarcodeDetection(code, points);
    } on ReaderException {
      // Try the perpendicular scan direction without camera restarts/model loads.
    }
  }
  return null;
}

String _expandUpce(String code) {
  if (code.length != 8) return code;
  final middle = code.substring(1, 7);
  final last = middle[5];
  final expanded = switch (last) {
    '0' ||
    '1' ||
    '2' => '${middle.substring(0, 2)}${last}0000${middle.substring(2, 5)}',
    '3' => '${middle.substring(0, 3)}00000${middle.substring(3, 5)}',
    '4' => '${middle.substring(0, 4)}00000${middle[4]}',
    _ => '${middle.substring(0, 5)}0000$last',
  };
  return '${code[0]}$expanded${code[7]}';
}
