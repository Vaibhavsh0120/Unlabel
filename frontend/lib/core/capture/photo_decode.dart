import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../models/app_failure.dart';

const _invalid = AppFailure(
  'invalid_photo',
  'Choose a clear JPEG, PNG or WebP package photo smaller than 12 MB.',
);

/// Read only format headers before any decode, including on web where encoded
/// ImageDescriptor.width/height are unsupported. Dimensions are resource bounds,
/// never evidence that the image or its label is valid.
ui.Size photoHeaderSize(Uint8List bytes) {
  if (bytes.length < 24 || bytes.length > 12 * 1024 * 1024) throw _invalid;
  final data = ByteData.sublistView(bytes);
  int? width, height;
  if (bytes.take(8).join(',') == '137,80,78,71,13,10,26,10' &&
      String.fromCharCodes(bytes.sublist(12, 16)) == 'IHDR') {
    width = data.getUint32(16);
    height = data.getUint32(20);
  } else if (bytes[0] == 255 && bytes[1] == 216) {
    var offset = 2;
    while (offset + 4 <= bytes.length) {
      if (bytes[offset++] != 255) throw _invalid;
      while (offset < bytes.length && bytes[offset] == 255) {
        offset++;
      }
      if (offset >= bytes.length) throw _invalid;
      final marker = bytes[offset++];
      if (marker == 0xd9 || marker == 0xda) break;
      if (marker == 0x01 || marker >= 0xd0 && marker <= 0xd7) continue;
      if (offset + 2 > bytes.length) throw _invalid;
      final length = data.getUint16(offset);
      if (length < 2 || offset + length > bytes.length) throw _invalid;
      if (const [
        0xc0,
        0xc1,
        0xc2,
        0xc3,
        0xc5,
        0xc6,
        0xc7,
        0xc9,
        0xca,
        0xcb,
        0xcd,
        0xce,
        0xcf,
      ].contains(marker)) {
        if (length < 8) throw _invalid;
        height = data.getUint16(offset + 3);
        width = data.getUint16(offset + 5);
        break;
      }
      offset += length;
    }
  } else if (String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    final kind = String.fromCharCodes(bytes.sublist(12, 16));
    if (kind == 'VP8X' && bytes.length >= 30) {
      width = 1 + bytes[24] + (bytes[25] << 8) + (bytes[26] << 16);
      height = 1 + bytes[27] + (bytes[28] << 8) + (bytes[29] << 16);
    } else if (kind == 'VP8L' && bytes.length >= 25 && bytes[20] == 0x2f) {
      final bits = data.getUint32(21, Endian.little);
      width = 1 + (bits & 0x3fff);
      height = 1 + ((bits >> 14) & 0x3fff);
    } else if (kind == 'VP8 ' &&
        bytes.length >= 30 &&
        bytes[23] == 0x9d &&
        bytes[24] == 0x01 &&
        bytes[25] == 0x2a) {
      width = data.getUint16(26, Endian.little) & 0x3fff;
      height = data.getUint16(28, Endian.little) & 0x3fff;
    }
  }
  if (width == null ||
      height == null ||
      width <= 0 ||
      height <= 0 ||
      width * height > 24000000 ||
      width > 24000 ||
      height > 24000) {
    throw _invalid;
  }
  return ui.Size(width.toDouble(), height.toDouble());
}

class DecodedPhoto {
  const DecodedPhoto(this.image, this.originalSize);
  final ui.Image image;
  final ui.Size originalSize;
}

/// Uses the platform decoder's upright dimensions for matching photo geometry.
/// Caller owns the returned image; codec and buffer are always released here.
Future<DecodedPhoto> decodePhoto(Uint8List bytes, {int maxEdge = 1600}) async {
  photoHeaderSize(bytes);
  ui.Size? original;
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final codec = await ui.instantiateImageCodecWithSize(
    buffer,
    getTargetSize: (width, height) {
      if (width <= 0 || height <= 0 || width * height > 24000000) {
        throw _invalid;
      }
      original = ui.Size(width.toDouble(), height.toDouble());
      final scale = math.min(1.0, maxEdge / math.max(width, height));
      return ui.TargetImageSize(
        width: math.max(1, (width * scale).round()),
        height: math.max(1, (height * scale).round()),
      );
    },
  );
  try {
    final image = (await codec.getNextFrame()).image;
    return DecodedPhoto(image, original!);
  } finally {
    codec.dispose();
  }
}
