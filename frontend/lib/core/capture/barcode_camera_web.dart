import 'dart:js_interop';

@JS('unlabelBarcodes.beginCameraStart')
external void beginBarcodeCameraStart();

@JS('unlabelBarcodes.finishCameraStart')
external void finishBarcodeCameraStart();

@JS('unlabelBarcodes.releaseCamera')
external void releaseBarcodeCamera();
