import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:zxing_lib/common.dart';
import 'package:zxing_lib/zxing.dart';

import '../models/extracted_label.dart';
import 'barcode_runtime.dart' as runtime;
import 'photo_decode.dart';

class BarcodeDetection {
  const BarcodeDetection(this.code, this.points);
  final String code;

  /// Actual decoder anchors/corners, normalized in the upright original photo.
  /// They are decoder geometry, not a verified printed-package boundary.
  final List<ui.Offset> points;
}

class BarcodeReader {
  static int _nextReader = 0;
  final int _reader = ++_nextReader;
  int _generation = 0;
  bool _disposed = false;
  String? _webJob;

  /// Preview reads trade a bounded 960 px frame and the expensive retry passes
  /// for a responsive camera. Explicit photographs retain all retry passes.
  Future<BarcodeDetection?> readPreview(Uint8List bytes) =>
      _read(bytes, maxEdge: 960, thorough: false);

  Future<BarcodeDetection?> read(Uint8List bytes) =>
      _read(bytes, maxEdge: 1400, thorough: true);

  Future<BarcodeDetection?> _read(
    Uint8List bytes, {
    required int maxEdge,
    required bool thorough,
  }) async {
    if (_disposed || bytes.isEmpty || bytes.length > 12 * 1024 * 1024) {
      return null;
    }
    final generation = ++_generation;
    final previousJob = _webJob;
    if (previousJob != null) runtime.cancelBarcodeRead(previousJob);
    final job = '$_reader:$generation';
    ui.Image? image;
    try {
      image = (await decodePhoto(bytes, maxEdge: maxEdge)).image;
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (rgba == null || _disposed || generation != _generation) return null;
      final pixels = rgba.buffer.asUint8List(
        rgba.offsetInBytes,
        rgba.lengthInBytes,
      );
      if (kIsWeb) {
        _webJob = job;
        final raw = await runtime.readBarcodePixels(
          pixels,
          image.width,
          image.height,
          thorough,
          job,
        );
        if (_disposed || generation != _generation || raw == null) return null;
        final value = jsonDecode(raw);
        if (value is! Map<String, dynamic> || value['text'] is! String) {
          return null;
        }
        final text = value['text'] as String;
        final code = value['format'] == 'UPCE' ? _expandUpce(text) : text;
        if (!validProductBarcode(code)) return null;
        final rawPoints = value['points'];
        final points = <ui.Offset>[];
        if (rawPoints is List && rawPoints.length <= 4) {
          for (final point in rawPoints) {
            if (point is! List ||
                point.length != 2 ||
                point[0] is! num ||
                point[1] is! num) {
              continue;
            }
            final x = (point[0] as num).toDouble();
            final y = (point[1] as num).toDouble();
            if (x.isFinite &&
                y.isFinite &&
                x >= 0 &&
                x <= 1 &&
                y >= 0 &&
                y <= 1) {
              points.add(ui.Offset(x, y));
            }
          }
        }
        return BarcodeDetection(code, List.unmodifiable(points));
      }
      final decoded = await compute(
        _decode,
        _BarcodePixels(image.width, image.height, pixels, thorough),
      );
      if (_disposed || generation != _generation || decoded == null) {
        return null;
      }
      return BarcodeDetection(decoded.code, List.unmodifiable(decoded.points));
    } catch (_) {
      return null;
    } finally {
      if (_webJob == job) _webJob = null;
      image?.dispose();
    }
  }

  void cancel() {
    _generation++;
    final job = _webJob;
    _webJob = null;
    if (job != null) runtime.cancelBarcodeRead(job);
  }

  void dispose() {
    _disposed = true;
    cancel();
  }
}

class _BarcodePixels {
  const _BarcodePixels(this.width, this.height, this.rgba, this.thorough);
  final int width, height;
  final Uint8List rgba;
  final bool thorough;
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
  Uint8List? perpendicular;
  // Keep the inexpensive center scans first, then inspect more rows and the
  // opposite print polarity. Input is capped at 1400 px and these six attempts
  // are finite; no camera loop or network decoder is started here.
  for (var pass = 0; pass < (pixels.thorough ? 3 : 1); pass++) {
    for (var rotated = 0; rotated < 2; rotated++) {
      final width = rotated == 0 ? pixels.width : pixels.height;
      final height = rotated == 0 ? pixels.height : pixels.width;
      var bytes = luminance;
      if (rotated == 1) {
        perpendicular ??= _rotateClockwise(
          luminance,
          pixels.width,
          pixels.height,
        );
        bytes = perpendicular;
      }
      final source = RGBLuminanceSource.orig(width, height, bytes);
      try {
        final result = MultiFormatReader().decode(
          BinaryBitmap(
            // Invert luminance itself: the decoder's alsoInverted matrix hint
            // does not change getBlackRow(), which EAN/UPC readers consume.
            HybridBinarizer(pass == 2 ? source.invert() : source),
          ),
          pass == 0 ? hints : hints.copyWith(tryHarder: true),
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
        // Try the next bounded direction/row-coverage/polarity combination.
      }
    }
  }
  return null;
}

Uint8List _rotateClockwise(Uint8List luminance, int width, int height) {
  final bytes = Uint8List(luminance.length);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      bytes[x * height + height - 1 - y] = luminance[y * width + x];
    }
  }
  return bytes;
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
