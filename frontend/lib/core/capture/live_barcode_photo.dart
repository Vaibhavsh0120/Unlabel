import 'dart:typed_data';

import 'live_barcode_photo_stub.dart'
    if (dart.library.io) 'live_barcode_photo_native.dart'
    as platform;

Future<T> withBarcodePhoto<T>(
  Uint8List bytes,
  Future<T> Function(String) analyze,
) => platform.withBarcodePhoto(bytes, analyze);
