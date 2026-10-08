import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../models/app_failure.dart';
import 'photo_decode.dart';

/// Re-encoding strips source metadata. Geometry follows the upright decoded image.
class VisionPhoto {
  const VisionPhoto(this.bytes, this.size);
  final Uint8List bytes;
  final ui.Size size;

  static Future<VisionPhoto> prepare(Uint8List source) async {
    if (source.isEmpty || source.length > 12 * 1024 * 1024) {
      throw const AppFailure(
        'invalid_photo',
        'Choose a photo smaller than 12 MB.',
      );
    }
    try {
      var edge = 1600;
      for (var attempt = 0; attempt < 7; attempt++) {
        final image = (await decodePhoto(source, maxEdge: edge)).image;
        try {
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          if (data != null && data.lengthInBytes <= 900000) {
            return VisionPhoto(
              data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
              ui.Size(image.width.toDouble(), image.height.toDouble()),
            );
          }
        } finally {
          image.dispose();
        }
        edge = (edge * .78).round();
      }
      throw const AppFailure(
        'invalid_photo',
        'Crop closer to the label and try again.',
      );
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
        'invalid_photo',
        'This image could not be opened. Choose another photo.',
      );
    }
  }
}
