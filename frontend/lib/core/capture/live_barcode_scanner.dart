import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/extracted_label.dart';
import 'barcode_reader.dart';
import 'barcode_camera.dart';
import 'barcode_runtime.dart';
import 'camera_framing.dart';
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
            cameraResolution: const Size(1920, 1080),
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
  final _photoReader = BarcodeReader();
  final _detections = StreamController<BarcodeDetection>.broadcast();
  Future<void> _pending = Future.value();
  Future<void>? _starting;
  bool _wanted = false, _disposed = false, _busy = false;
  int _revision = 0;
  int _photoGeneration = 0;
  String? _error, _acceptedCode;
  double _zoomOrigin = 0;
  double? _nextZoom;
  Future<void>? _zoomOperation;

  Stream<BarcodeDetection> get detections => _detections.stream;
  bool get ready => !_disposed && _wanted && _controller.value.isRunning;
  bool get busy => _busy || _controller.value.isStarting;
  String? get error => _error;
  bool get canToggleTorch =>
      ready && _controller.value.torchState != TorchState.unavailable;
  bool get torchOn => _controller.value.torchState == TorchState.on;
  bool get canSwitchCamera =>
      ready && (_controller.value.availableCameras ?? 1) > 1;

  void beginZoom() {
    if (!ready) return;
    if (kIsWeb) {
      beginBarcodeCameraZoom();
    } else {
      _zoomOrigin = _controller.value.zoomScale.clamp(0, 1);
    }
  }

  Future<void> updateZoom(double scale) {
    if (!ready || !scale.isFinite || scale <= 0) return Future.value();
    if (kIsWeb) return zoomBarcodeCamera(scale);
    _nextZoom = (_zoomOrigin + math.log(scale) * .45).clamp(0, 1);
    return _zoomOperation ??= _applyZoom().whenComplete(
      () => _zoomOperation = null,
    );
  }

  Future<void> _applyZoom() async {
    final revision = _revision;
    while (_nextZoom != null && ready && revision == _revision) {
      final scale = _nextZoom!;
      _nextZoom = null;
      try {
        await _controller.setZoomScale(scale);
      } catch (_) {
        // A fixed-focus or unsupported camera must keep scanning.
      }
    }
  }

  Future<void> focusAt(Offset position, Size viewport) async {
    if (!ready || kIsWeb || viewport.isEmpty) return;
    var point = Offset(
      position.dx / viewport.width,
      position.dy / viewport.height,
    );
    final state = _controller.value;
    // Match the SDK's texture orientation used for its visible scan window.
    final source = switch (state.deviceOrientation) {
      DeviceOrientation.landscapeLeft ||
      DeviceOrientation.landscapeRight => state.size.flipped,
      DeviceOrientation.portraitUp ||
      DeviceOrientation.portraitDown => state.size,
    };
    if (!source.isEmpty) {
      final visible = cameraVisibleRect(
        source,
        viewport,
        previewAspectRatio: source.aspectRatio,
      );
      point = Offset(
        (visible.left + point.dx * visible.width) / source.width,
        (visible.top + point.dy * visible.height) / source.height,
      );
    }
    if (_controller.value.cameraDirection == CameraFacing.front) {
      point = Offset(1 - point.dx, point.dy);
    }
    try {
      await _controller.setFocusPoint(
        Offset(point.dx.clamp(0, 1), point.dy.clamp(0, 1)),
      );
    } catch (_) {
      /* Fixed-focus cameras still decode normally. */
    }
  }

  void cancelPhotoRead() {
    _photoGeneration++;
    _photoReader.cancel();
  }

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
    cancelPhotoRead();
    _nextZoom = null;
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
    if (_disposed || bytes.isEmpty || bytes.length > 12 * 1024 * 1024) {
      return null;
    }
    final generation = ++_photoGeneration;
    if (!kIsWeb) {
      try {
        final capture = await withBarcodePhoto(
          bytes,
          (path) => _controller.analyzeImage(path, formats: productFormats),
        );
        final found = capture == null ? null : productBarcodeDetection(capture);
        if (_disposed || generation != _photoGeneration) return null;
        if (found != null) return found;
      } catch (_) {
        // The independent local reader also handles devices without SDK stills.
      }
    }
    return _disposed || generation != _photoGeneration
        ? null
        : _photoReader.read(bytes);
  }

  Widget buildPreview() => LayoutBuilder(
    builder: (context, constraints) => GestureDetector(
      onTapUp: (details) =>
          unawaited(focusAt(details.localPosition, constraints.biggest)),
      onScaleStart: (_) => beginZoom(),
      onScaleUpdate: (details) {
        if (details.pointerCount >= 2) unawaited(updateZoom(details.scale));
      },
      child: MobileScanner(
        controller: _controller,
        fit: BoxFit.cover,
        scanWindow: (Offset.zero & constraints.biggest).deflate(24),
        scanWindowUpdateThreshold: 2,
        useAppLifecycleState: false,
        // Focus is handled in preview coordinates above; the SDK uses screen
        // coordinates on native and throws on web. Web keeps continuous focus.
        tapToFocus: false,
        onDetect: (capture) {
          if (!ready || _acceptedCode != null) return;
          final detection = productBarcodeDetection(capture);
          if (detection == null) return;
          _acceptedCode = detection.code;
          _detections.add(detection);
        },
        onDetectError: (error, _) {
          if (_disposed) return;
          _error =
              'The barcode reader could not start. Retry or choose a photo.';
          _notify();
        },
        errorBuilder: (_, _) => const SizedBox.shrink(),
        placeholderBuilder: (_) => const SizedBox.shrink(),
      ),
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
    _nextZoom = null;
    _photoReader.dispose();
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
