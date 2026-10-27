import 'dart:typed_data';

Future<void> prepareBarcodeRuntime() async {}

Future<String?> readBarcodePixels(
  Uint8List pixels,
  int width,
  int height,
  bool thorough,
  String job,
) async => null;

void cancelBarcodeRead(String job) {}
