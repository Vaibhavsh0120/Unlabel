import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/extracted_label.dart';
import 'barcode_reader.dart';
import 'barcode_camera.dart';
import 'barcode_runtime.dart';
import 'live_barcode_photo.dart';

/// A single owner of the maintained scanner SDK's camera and decoder.
/// No raw camera frames or package photographs are sent to a network service.
class LiveBarcodeScanner extends ChangeNotifier {
  LiveBarcodeScanner({MobileScannerController? controller})
    : _controller =
          controller ??
          MobileScannerController(
            autoStart: false,
            facing: CameraFacing.back,
            detectionSpeed: DetectionSpeed.normal,
            detectionTimeoutMs: 350,
            formats: productFormats,
            cameraResolution: const Size(1280, 720),
            autoZoom: true,
          ) {
    _controller.addListener(_changed);
  }

  static const productFormats = [
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.upcA,
    BarcodeFormat.upcE,
  ];
  final MobileScannerController _controller;
  final _detections = StreamController<BarcodeDetection>.broadcast();
  Future<void> _pending = Future.value();
  Future<void>? _starting;
  bool _wanted = false, _disposed = false, _busy = false;
  int _revision = 0;
  String? _error, _acceptedCode;

  Stream<BarcodeDetection> get detections => _detections.stream;
  bool get ready => !_disposed && _wanted && _controller.value.isRunning;
  bool get busy => _busy || _controller.value.isStarting;
  String? get error => _error;
  bool get canToggleTorch =>
      ready && _controller.value.torchState != TorchState.unavailable;
  bool get torchOn => _controller.value.torchState == TorchState.on;
  bool get canSwitchCamera =>
      ready && (_controller.value.availableCameras ?? 1) > 1;

  Future<void> start() {
    if (_disposed || ready) return Future.value();
    if (_wanted && _starting != null) return _starting!;
    _wanted = true;
    _busy = true;
    _error = null;
    _acceptedCode = null;
    final revision = ++_revision;
    _notify();
    final operation = _serialize(() async {
      if (!_current(revision)) return;
      try {
        if (kIsWeb) {
          MobileScannerPlatform.instance.setWebBarcodeReader(
            WebBarcodeReader.zxingWasm,
          );
          MobileScannerPlatform.instance.setBarcodeLibraryScriptUrl(
            Uri.base.resolve('vendor/zxing-wasm/3.1.3/index.js').toString(),
          );
        }
        await prepareBarcodeRuntime();
        if (!_current(revision)) return;
        beginBarcodeCameraStart();
        try {
          await _controller.start();
        } finally {
          finishBarcodeCameraStart();
        }
        if (_current(revision) &&
            !kIsWeb &&
            defaultTargetPlatform == TargetPlatform.iOS) {
          // Prefer the device's macro-capable rear lens when it exposes one.
          // Older iPhones safely retain their ordinary autofocus camera.
          try {
            final best = await _controller.getBestCloseRangeScanningLens();
            final supported = await _controller.getSupportedLenses(
              facing: CameraFacing.back,
            );
            if (_current(revision) &&
                best != null &&
                best != _controller.value.cameraLensType &&
                supported.contains(best)) {
              await _controller.switchCamera(
                SelectCamera(
                  facingDirection: CameraFacing.back,
                  lensType: best,
                ),
              );
            }
          } catch (_) {
            // Lens discovery is optional; never lose a working camera for it.
          }
        }
        if (!_current(revision)) {
          try {
            await _controller.stop();
          } finally {
            releaseBarcodeCamera();
          }
        }
      } catch (error) {
        releaseBarcodeCamera();
        if (_current(revision)) _error = _message(error);
      } finally {
        if (_current(revision)) {
          _busy = false;
          _starting = null;
          _notify();
        }
      }
    });
    _starting = operation;
    return operation;
  }

  Future<void> stop() {
    if (_disposed) return _pending;
    _wanted = false;
    _revision++;
    _busy = false;
    _starting = null;
    _notify();
    return _serialize(() async {
      try {
        await _controller.stop();
      } finally {
        releaseBarcodeCamera();
      }
    });
  }

  Future<void> toggleTorch() async {
    try {
      await _controller.toggleTorch();
    } catch (_) {
      _error = 'Flash is unavailable. Use brighter lighting.';
      _notify();
    }
  }

  Future<void> switchCamera() async {
    if (!canSwitchCamera) return;
    try {
      await _serialize(() async {
        releaseBarcodeCamera();
        beginBarcodeCameraStart();
        try {
          await _controller.switchCamera();
        } finally {
          finishBarcodeCameraStart();
        }
      });
    } catch (_) {
      releaseBarcodeCamera();
      _error = 'This camera could not open. Retry or choose a photo.';
      _notify();
    }
  }

  Future<BarcodeDetection?> analyzeBytes(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > 12 * 1024 * 1024) return null;
    final capture = await withBarcodePhoto(
      bytes,
      (path) => _controller.analyzeImage(path, formats: productFormats),
    );
    return capture == null ? null : productBarcodeDetection(capture);
  }

  Widget buildPreview() => LayoutBuilder(
    builder: (context, constraints) => MobileScanner(
      controller: _controller,
      fit: BoxFit.cover,
      scanWindow: (Offset.zero & constraints.biggest).deflate(24),
      scanWindowUpdateThreshold: 2,
      useAppLifecycleState: false,
      tapToFocus: true,
      onDetect: (capture) {
        if (!ready || _acceptedCode != null) return;
        final detection = productBarcodeDetection(capture);
        if (detection == null) return;
        _acceptedCode = detection.code;
        _detections.add(detection);
      },
      onDetectError: (error, _) {
        if (_disposed) return;
        _error = 'The barcode reader could not start. Retry or choose a photo.';
        _notify();
      },
      errorBuilder: (_, _) => const SizedBox.shrink(),
      placeholderBuilder: (_) => const SizedBox.shrink(),
    ),
  );

  bool _current(int revision) => !_disposed && _wanted && revision == _revision;
  Future<void> _serialize(Future<void> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void _changed() {
    if (_disposed) return;
    final exception = _controller.value.error;
    if (exception != null) _error = _message(exception);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  static String _message(Object error) {
    if (error is MobileScannerException &&
        error.errorCode == MobileScannerErrorCode.permissionDenied) {
      return 'Camera permission is needed. Allow it in browser or device settings, then retry, or choose a photo.';
    }
    return 'The barcode camera could not start. Retry or choose a photo.';
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _wanted = false;
    _revision++;
    _controller.removeListener(_changed);
    unawaited(
      _serialize(() async {
        try {
          await _controller.dispose();
        } finally {
          releaseBarcodeCamera();
        }
      }),
    );
    unawaited(_detections.close());
    super.dispose();
  }
}

/// Keep only food-product symbologies and reject partial/invalid SDK values.
BarcodeDetection? productBarcodeDetection(BarcodeCapture capture) {
  for (final barcode in capture.barcodes) {
    if (!LiveBarcodeScanner.productFormats.contains(barcode.format)) continue;
    var code = barcode.rawValue?.trim();
    if (code == null) continue;
    if (barcode.format == BarcodeFormat.upcE && code.length == 8) {
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
      code = '${code[0]}$expanded${code[7]}';
    }
    if (!validProductBarcode(code)) continue;
    final size = capture.size;
    final points = size.isEmpty
        ? const <Offset>[]
        : barcode.corners
              .map(
                (point) => Offset(
                  (point.dx / size.width).clamp(0, 1),
                  (point.dy / size.height).clamp(0, 1),
                ),
              )
              .toList();
    return BarcodeDetection(code, List.unmodifiable(points));
  }
  return null;
}
