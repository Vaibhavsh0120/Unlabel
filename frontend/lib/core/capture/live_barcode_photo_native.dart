import 'dart:io';
import 'dart:typed_data';

/// SDK analysis needs a file path. Photos live only in a private temporary
/// directory for this request and are removed whether decoding succeeds or fails.
Future<T> withBarcodePhoto<T>(
  Uint8List bytes,
  Future<T> Function(String) analyze,
) async {
  final directory = await Directory.systemTemp.createTemp('unlabel-barcode-');
  final file = File('${directory.path}/capture.jpg');
  try {
    await file.writeAsBytes(bytes, flush: true);
    return await analyze(file.path);
  } finally {
    if (await file.exists()) await file.delete();
    await directory.delete();
  }
}
