import 'dart:js_interop';

@JS('unlabelBarcodes.beginCameraStart')
external void beginBarcodeCameraStart();

@JS('unlabelBarcodes.finishCameraStart')
external void finishBarcodeCameraStart();

@JS('unlabelBarcodes.releaseCamera')
external void releaseBarcodeCamera();

@JS('unlabelBarcodes.beginZoom')
external void beginBarcodeCameraZoom();

@JS('unlabelBarcodes.zoom')
external JSPromise<JSAny?> _zoom(JSNumber scale);

Future<void> zoomBarcodeCamera(double scale) async {
  await _zoom(scale.toJS).toDart;
}
