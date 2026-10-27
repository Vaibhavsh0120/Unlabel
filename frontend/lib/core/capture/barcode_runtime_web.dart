import 'dart:js_interop';
import 'dart:typed_data';

@JS('unlabelBarcodes.prepare')
external JSPromise<JSAny?> _prepare();

@JS('unlabelBarcodes.read')
external JSPromise<JSString> _read(
  JSUint8Array pixels,
  JSNumber width,
  JSNumber height,
  JSBoolean thorough,
  JSString job,
);

@JS('unlabelBarcodes.cancel')
external void _cancel(JSString job);

/// The camera SDK and still-photo reader share one pinned, same-origin runtime.
Future<void> prepareBarcodeRuntime() async {
  await _prepare().toDart;
}

Future<String?> readBarcodePixels(
  Uint8List pixels,
  int width,
  int height,
  bool thorough,
  String job,
) async => (await _read(
  pixels.toJS,
  width.toJS,
  height.toJS,
  thorough.toJS,
  job.toJS,
).toDart).toDart;

void cancelBarcodeRead(String job) {
  try {
    _cancel(job.toJS);
  } catch (_) {
    // Generation checks in BarcodeReader also discard a late result.
  }
}
