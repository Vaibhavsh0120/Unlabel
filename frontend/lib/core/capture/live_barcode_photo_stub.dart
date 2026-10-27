import 'dart:typed_data';

Future<T> withBarcodePhoto<T>(
  Uint8List bytes,
  Future<T> Function(String) analyze,
) => Future.error(UnsupportedError('Use the web barcode image reader.'));
