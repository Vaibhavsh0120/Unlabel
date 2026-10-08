import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The small platform boundary keeps camera lifecycle tests off real hardware.
abstract interface class LiveCameraPlatform {
  bool get isSupported;
  Future<List<CameraDescription>> availableCameras();
  LiveCameraSession createSession(
    CameraDescription description, {
    required bool enableAudio,
  });
}

abstract interface class LiveCameraSession {
  Listenable get changes;
  bool get hasError;
  double get aspectRatio;
  Future<void> initialize();
  Future<XFile> takePicture();
  Widget buildPreview();
  Future<void> dispose();
}

class LiveCameraException implements Exception {
  const LiveCameraException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A route owns this object and calls [stop] while covered or backgrounded.
///
/// Readiness is invalidated immediately on stop/dispose. Native initialization,
/// capture and disposal are serialized; late permission results cannot reopen
/// a hidden page. Captured bytes are returned only to the caller, never stored
/// or uploaded here.
class LiveCamera extends ChangeNotifier {
  LiveCamera({LiveCameraPlatform? platform})
    : _platform = platform ?? const PluginLiveCameraPlatform();

  static const int maxCaptureBytes = 12 * 1024 * 1024;

  final LiveCameraPlatform _platform;
  LiveCameraSession? _session;
  Future<void> _pending = Future<void>.value();
  Future<void>? _starting;
  bool _disposed = false;
  bool _wanted = false;
  bool _busy = false;
  bool _ready = false;
  String? _error;
  int _revision = 0;

  bool get busy => _busy;
  bool get ready => !_disposed && _wanted && _ready;
  String? get error => _error;
  double get aspectRatio => ready ? _session!.aspectRatio : 1;

  Future<void> start() {
    if (_disposed || ready) return Future<void>.value();
    if (_wanted && _busy && _starting != null) return _starting!;

    _wanted = true;
    final revision = ++_revision;
    _busy = true;
    _error = null;
    _notify();
    final starting = _serialize<void>(() async {
      if (!_current(revision)) return;
      await _release();
      if (!_current(revision)) return;
      try {
        if (!_platform.isSupported) {
          throw const LiveCameraException(
            'Live camera is available on Android, iPhone, iPad and supported '
            'web browsers. You can choose a package photo instead.',
          );
        }
        final cameras = await _platform.availableCameras();
        if (!_current(revision)) return;
        if (cameras.isEmpty) {
          throw const LiveCameraException(
            'No camera was found. Connect a camera and retry, or choose a photo.',
          );
        }
        final description = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        );
        final session = _platform.createSession(
          description,
          enableAudio: false,
        );
        _session = session;
        session.changes.addListener(_sessionChanged);
        await session.initialize();
        if (!_current(revision)) {
          await _release();
          return;
        }
        if (session.hasError) {
          throw const LiveCameraException(
            'The camera could not start. Retry or choose a photo.',
          );
        }
        _ready = true;
        _busy = false;
        _notify();
      } catch (error) {
        await _release();
        if (_current(revision)) {
          _ready = false;
          _busy = false;
          _error = _message(error);
          _notify();
        }
      }
    });
    _starting = starting;
    return starting;
  }

  Future<void> stop() {
    if (_disposed) return _pending;
    _wanted = false;
    _revision++;
    _ready = false;
    _busy = false;
    _error = null;
    _notify();
    return _serialize<void>(_release);
  }

  Future<Uint8List> capture() => _capture<Uint8List>((file) async {
    if (await file.length() > maxCaptureBytes) {
      throw const LiveCameraException(
        'This photo is too large. Retake it or choose a photo under 12 MB.',
      );
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > maxCaptureBytes) {
      throw const LiveCameraException(
        'This photo could not be read. Retake it or choose another photo.',
      );
    }
    return bytes;
  });

  Future<XFile> captureFile() => _capture<XFile>((file) async => file);

  Future<T> _capture<T>(Future<T> Function(XFile file) read) {
    if (!ready || _busy) {
      return Future<T>.error(
        const LiveCameraException('Wait for the camera to be ready.'),
      );
    }
    final revision = _revision;
    _busy = true;
    _error = null;
    _notify();
    return _serialize<T>(() async {
      try {
        if (!_current(revision) || !_ready) throw _cancelled;
        final file = await _session!.takePicture();
        if (!_current(revision)) throw _cancelled;
        final result = await read(file);
        if (!_current(revision)) throw _cancelled;
        return result;
      } catch (error) {
        final message = _message(
          error,
          fallback:
              'The photo could not be captured. Retake it or choose a photo.',
        );
        if (_current(revision)) _error = message;
        throw LiveCameraException(message);
      } finally {
        if (_current(revision)) {
          _busy = false;
          _notify();
        }
      }
    });
  }

  static const _cancelled = LiveCameraException(
    'Camera capture was cancelled.',
  );

  Widget buildPreview() =>
      ready ? _session!.buildPreview() : const SizedBox.shrink();

  bool _current(int revision) => !_disposed && _wanted && revision == _revision;

  void _sessionChanged() {
    if (!ready || !_session!.hasError) return;
    _revision++;
    _ready = false;
    _busy = false;
    _error = 'The camera connection was interrupted. Retry or choose a photo.';
    _notify();
    unawaited(_serialize<void>(_release));
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _release() async {
    final session = _session;
    _session = null;
    if (session == null) return;
    session.changes.removeListener(_sessionChanged);
    try {
      await session.dispose();
    } catch (_) {
      // A disconnected device can fail disposal. No stale session is reused.
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  static String _message(Object error, {String? fallback}) {
    if (error is LiveCameraException) return error.message;
    final code = switch (error) {
      CameraException() => error.code,
      PlatformException() => error.code,
      _ => '',
    };
    return switch (code) {
      'CameraAccessDeniedWithoutPrompt' =>
        'Camera access is off. Enable it in device Settings, then retry.',
      'CameraAccessRestricted' => 'Camera access is restricted on this device. You can choose a photo instead.',
      'CameraAccessDenied' ||
      'cameraPermission' ||
      'permissionDenied' ||
      'NotAllowedError' =>
        'Camera permission is needed for a live preview. Allow it in device or '
            'browser settings, then retry, or choose a photo.',
      'NotFoundError' || 'cameraNotFound' =>
        'No camera was found. Connect a camera and retry, or choose a photo.',
      'NotReadableError' || 'cameraNotReadable' => 'The camera is in use or unavailable. Close other camera apps and retry.',
      'SecurityError' || 'notSupported' || 'NotSupportedError' =>
        'This browser cannot open the camera here. Use HTTPS or localhost in a '
            'supported browser, or choose a photo.',
      _ => fallback ?? 'The camera could not start. Retry or choose a photo.',
    };
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _wanted = false;
    _revision++;
    _ready = false;
    _busy = false;
    unawaited(_serialize<void>(_release));
    super.dispose();
  }
}

class PluginLiveCameraPlatform implements LiveCameraPlatform {
  const PluginLiveCameraPlatform();

  @override
  bool get isSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<List<CameraDescription>> availableCameras() =>
      availableCamerasFromPlugin();

  @override
  LiveCameraSession createSession(
    CameraDescription description, {
    required bool enableAudio,
  }) => _PluginLiveCameraSession(
    CameraController(
      description,
      ResolutionPreset.veryHigh,
      enableAudio: enableAudio,
    ),
  );
}

// The adapter method has the same name as the package function.
Future<List<CameraDescription>> availableCamerasFromPlugin() =>
    availableCameras();

class _PluginLiveCameraSession implements LiveCameraSession {
  _PluginLiveCameraSession(this.controller);

  final CameraController controller;

  @override
  Listenable get changes => controller;
  @override
  bool get hasError => controller.value.hasError;
  @override
  double get aspectRatio => controller.value.aspectRatio;
  @override
  Future<void> initialize() => controller.initialize();
  @override
  Future<XFile> takePicture() => controller.takePicture();
  @override
  Widget buildPreview() => CameraPreview(controller);
  @override
  Future<void> dispose() => controller.dispose();
}
