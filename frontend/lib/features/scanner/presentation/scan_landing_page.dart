import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/capture/live_camera.dart';
import '../../../core/capture/photo_decode.dart';
import '../../../core/capture/automatic_label_reader.dart';
import '../../../core/capture/barcode_reader.dart';
import '../../../core/capture/live_barcode_scanner.dart';
import '../../../core/models/extracted_label.dart';
import '../../../core/models/app_failure.dart';
import '../../../core/interaction/ui_feedback.dart';
import 'ui_components.dart';
import 'scan_processing_overlay.dart';

class ScanLandingPage extends StatefulWidget {
  const ScanLandingPage({
    required this.reader,
    required this.onResult,
    this.camera,
    this.pickPhoto,
    this.barcodeScanner,
    this.barcodeScannerFactory,
    super.key,
  });
  final AutomaticLabelReader reader;
  final Future<void> Function(AutomaticScanResult, Uint8List?) onResult;
  final LiveCamera? camera;
  final Future<Uint8List?> Function()? pickPhoto;
  final LiveBarcodeScanner? barcodeScanner;
  final LiveBarcodeScanner Function()? barcodeScannerFactory;

  @override
  State<ScanLandingPage> createState() => _ScanLandingPageState();
}

class _ScanLandingPageState extends State<ScanLandingPage>
    with WidgetsBindingObserver {
  late final LiveCamera _camera = widget.camera ?? LiveCamera();
  final _photos = <int, Uint8List>{};
  final _sizes = <int, Size>{};
  late final _reader = widget.reader;
  AutomaticScanResult? _result;
  bool _reading = false;
  int _mode = 2;
  Size _previewSize = Size.zero;
  int _photoRevision = 0;
  bool _working = false, _routeOpen = false, _foreground = true;
  String? _photoError;
  late final _barcodeScanner =
      widget.barcodeScanner ??
      widget.barcodeScannerFactory?.call() ??
      LiveBarcodeScanner();
  StreamSubscription<BarcodeDetection>? _barcodeSubscription;
  bool _takingBarcodePhoto = false;
  String? _detectedBarcode;
  int _cameraSyncRevision = 0;
  bool get _usesBarcodeSdk =>
      widget.barcodeScanner != null ||
      widget.barcodeScannerFactory != null ||
      widget.camera == null;
  bool get _barcodeMode =>
      _usesBarcodeSdk && _mode == 2 && !_takingBarcodePhoto;
  bool get _previewReady =>
      _barcodeMode ? _barcodeScanner.ready : _camera.ready;
  bool get _previewBusy => _barcodeMode ? _barcodeScanner.busy : _camera.busy;
  String? get _previewError =>
      _barcodeMode ? _barcodeScanner.error : _camera.error;

  Future<void> _stopCameras() async {
    await _barcodeScanner.stop();
    await _camera.stop();
  }

  Future<void> _barcodeDetected(BarcodeDetection detection) async {
    if (!mounted ||
        !_foreground ||
        _blocked ||
        _mode != 2 ||
        _detectedBarcode != null) {
      return;
    }
    final revision = ++_photoRevision;
    setState(() {
      _reading = true;
      _detectedBarcode = detection.code;
      _photoError = null;
    });
    await _stopCameras();
    try {
      final result = await _reader.lookupBarcode(detection.code);
      if (!mounted || revision != _photoRevision) return;
      setState(() => _result = result);
      if (!_foreground) return;
      _routeOpen = true;
      await widget.onResult(result, null);
      unawaited(UiFeedback.confirmed());
    } catch (_) {
      if (mounted && revision == _photoRevision) {
        setState(() => _photoError = 'Could not open this product. Try again.');
      }
    } finally {
      _routeOpen = false;
      if (mounted && revision == _photoRevision) {
        setState(() => _reading = false);
        unawaited(_syncCamera());
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _camera.addListener(_cameraChanged);
    _barcodeScanner.addListener(_cameraChanged);
    _barcodeSubscription = _barcodeScanner.detections.listen(_barcodeDetected);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Lost-picker recovery can take seconds on Android. It must not hold up
      // camera permission/first preview on every ordinary Scan entry.
      unawaited(_syncCamera());
      unawaited(_restoreGallery());
    });
  }

  Future<void> _restoreGallery() async {
    if (!mounted) return;
    final revision = _photoRevision;
    // Android may recreate the activity while its system photo picker is open.
    // Restore only that pending selection; photos remain in this route's memory.
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        widget.pickPhoto == null) {
      try {
        final response = await ImagePicker().retrieveLostData().timeout(
          const Duration(seconds: 5),
        );
        if (!mounted || revision != _photoRevision) return;
        final files = response.files;
        if (files != null && files.isNotEmpty) {
          final bytes = await _readPhoto(files.first);
          if (!mounted || revision != _photoRevision) return;
          setState(() {
            _mode = 1;
            _photos[1] = bytes;
          });
          unawaited(_syncCamera());
          unawaited(_analyze());
        } else if (response.exception != null) {
          setState(
            () => _photoError =
                'The photo selection was interrupted. Choose the image again.',
          );
        }
      } catch (_) {
        if (mounted && revision == _photoRevision) {
          setState(
            () => _photoError = 'The photo selection could not be restored. Choose the image again.',
          );
        }
      }
    }
  }

  void _cameraChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _syncCamera() async {
    if (!mounted) return;
    final revision = ++_cameraSyncRevision;
    if (_foreground &&
        !_routeOpen &&
        !_working &&
        !_reading &&
        _photos[_mode] == null) {
      if (_barcodeMode) {
        await _camera.stop();
        if (mounted &&
            revision == _cameraSyncRevision &&
            _detectedBarcode == null) {
          await _barcodeScanner.start();
        }
      } else {
        await _barcodeScanner.stop();
        if (mounted && revision == _cameraSyncRevision) await _camera.start();
      }
    } else {
      await _stopCameras();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;

    unawaited(_syncCamera());
  }

  Future<void> _route(Future<void> Function() open) async {
    if (_working || _routeOpen) return;
    _photoRevision++;
    _routeOpen = true;

    await _stopCameras();
    if (!mounted) return;
    try {
      await open();
    } on AppFailure catch (error) {
      if (mounted) setState(() => _photoError = error.userMessage);
    } catch (_) {
      if (mounted) {
        setState(() => _photoError = 'Results could not open. Try again.');
      }
    } finally {
      _routeOpen = false;
      if (mounted) unawaited(_syncCamera());
    }
  }

  Future<void> _capture() async {
    if (_working || _reading || !_previewReady || _previewSize.isEmpty) return;
    final revision = ++_photoRevision;
    final mode = _mode;
    final viewport = _previewSize;
    setState(() {
      _working = true;
      _photoError = null;
    });

    try {
      if (_barcodeMode) {
        setState(() => _takingBarcodePhoto = true);
        await _barcodeScanner.stop();
        await _camera.start();
      }
      if (!mounted || revision != _photoRevision || !_camera.ready) return;
      final bytes = await _camera.captureFramed(viewport);
      if (!mounted || revision != _photoRevision || mode != _mode) return;
      if (viewport != _previewSize) {
        setState(
          () => _photoError = 'The camera view changed. Take the photo again.',
        );
        return;
      }
      if (bytes.length > LiveCamera.maxCaptureBytes) {
        throw StateError('large_photo');
      }
      setState(() => _photos[mode] = bytes);
      unawaited(_analyze());
      unawaited(UiFeedback.confirmed());
    } catch (_) {
      if (mounted && revision == _photoRevision) {
        setState(
          () => _photoError =
              'Could not capture this photo. Try again or use Gallery.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
          _takingBarcodePhoto = false;
        });
        unawaited(_syncCamera());
      }
    }
  }

  Future<void> _gallery() async {
    if (_working || _reading) return;
    final revision = ++_photoRevision;
    final mode = _mode;
    setState(() {
      _working = true;
      _photoError = null;
    });

    await _stopCameras();
    try {
      if (!mounted) return;
      final bytes = widget.pickPhoto != null
          ? await widget.pickPhoto!()
          : await _pickPhoto();
      if (!mounted ||
          revision != _photoRevision ||
          mode != _mode ||
          bytes == null) {
        return;
      }
      if (bytes.isEmpty || bytes.length > LiveCamera.maxCaptureBytes) {
        throw StateError('large_photo');
      }
      setState(() => _photos[mode] = bytes);
      unawaited(_analyze());
      unawaited(UiFeedback.selection());
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _photoError = 'Could not open that image. Choose another photo.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
          _takingBarcodePhoto = false;
        });
        unawaited(_syncCamera());
      }
    }
  }

  Future<bool> _allowCloud() async {
    final preferences = await SharedPreferences.getInstance();
    final previous = preferences.getBool('unlabel.photo-reading-consent.v2');
    if (previous != null) return previous;
    if (!mounted) return false;
    final allowed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Automatic photo reading'),
        content: const Text(
          'Send package photos to our backend and its Gemini or OpenAI service for automatic reading. Our backend does not save photos. Compatible product facts from back labels are added automatically to the shared catalogue as unverified machine readings. Original sources and disagreements are retained; no personal profile data is shared. Google may use free-tier inputs to improve its services; provider retention terms apply. Only photograph the package. You can also read on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('On this device'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Use automatic AI'),
          ),
        ],
      ),
    );
    if (allowed != null) {
      await preferences.setBool('unlabel.photo-reading-consent.v2', allowed);
    }
    return allowed ?? false;
  }

  Future<void> _analyze() async {
    if (_reading || !mounted || _photos.isEmpty) return;
    final revision = _photoRevision;

    setState(() {
      _reading = true;
      _result = null;
      _photoError = null;
    });
    await _stopCameras();
    try {
      for (final entry in _photos.entries.toList()) {
        final photo = await decodePhoto(entry.value, maxEdge: 1);
        _sizes[entry.key] = photo.originalSize;
        photo.image.dispose();
      }
      final AutomaticScanResult result;
      if (_usesBarcodeSdk && _mode == 2) {
        final detection = kIsWeb
            ? await BarcodeReader().read(_photos[2]!)
            : await _barcodeScanner.analyzeBytes(_photos[2]!);
        if (!mounted || revision != _photoRevision) return;
        result = detection == null
            ? const AutomaticScanResult()
            : await _reader.lookupBarcode(detection.code);
      } else {
        result = await _reader.read(
          Map.unmodifiable(_photos),
          allowCloud: _allowCloud,
        );
      }
      if (!mounted || revision != _photoRevision) return;
      setState(() {
        _result = result;
        if (!result.useful) {
          _photoError = 'No readable product information yet. Try a closer, clearer photo.';
        }
      });
      if (_foreground &&
          _mode == 2 &&
          (result.barcode != null ||
              result.report != null ||
              result.candidates.isNotEmpty)) {
        _routeOpen = true;
        try {
          await widget.onResult(result, _photos[0]);
        } finally {
          _routeOpen = false;
        }
      }
    } catch (_) {
      if (mounted && revision == _photoRevision) {
        setState(
          () => _photoError = 'Could not read this photo. Retake it in good light or add the other side.',
        );
      }
    } finally {
      if (mounted && revision == _photoRevision) {
        setState(() => _reading = false);
        unawaited(_syncCamera());
      }
    }
  }

  void _stopReading() {
    _photoRevision++;
    _reader.cancel();
    setState(() {
      _reading = false;
      _detectedBarcode = null;
      _photoError = 'Reading stopped. You can retry or retake the photo.';
    });
    unawaited(_syncCamera());
  }

  Future<Uint8List?> _pickPhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    return file == null ? null : _readPhoto(file);
  }

  Future<Uint8List> _readPhoto(XFile file) async {
    if (await file.length().timeout(const Duration(seconds: 5)) >
        LiveCamera.maxCaptureBytes) {
      throw StateError('large_photo');
    }
    final bytes = await file.readAsBytes().timeout(const Duration(seconds: 10));
    if (bytes.isEmpty || bytes.length > LiveCamera.maxCaptureBytes) {
      throw StateError('invalid_photo');
    }
    return bytes;
  }

  void _selectMode(int mode) {
    if (_working || _reading || _mode == mode) return;
    _photoRevision++;

    setState(() {
      _mode = mode;
      _detectedBarcode = null;
      _result = null;
      _photoError = null;
    });
    unawaited(UiFeedback.selection());
    unawaited(_syncCamera());
  }

  @override
  void dispose() {
    unawaited(_barcodeSubscription?.cancel());
    _barcodeScanner.removeListener(_cameraChanged);
    _barcodeScanner.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _reader.dispose();
    _camera.removeListener(_cameraChanged);
    if (widget.camera == null) {
      _camera.dispose();
    } else {
      unawaited(_camera.stop());
    }
    super.dispose();
  }

  bool get _blocked => _working || _reading || _routeOpen;

  String get _primaryLabel => _reading
      ? 'Reading photo…'
      : _working
      ? 'Working…'
      : _result?.useful == true
      ? 'View results'
      : _photos[_mode] != null
      ? 'Read photo again'
      : 'Click Photo';

  VoidCallback? get _primaryAction => _blocked
      ? null
      : _result?.useful == true
      ? () => _route(() => widget.onResult(_result!, _photos[0]))
      : _photos[_mode] != null
      ? _analyze
      : _previewReady
      ? _capture
      : null;

  Future<void> _cameraControl(Future<void> Function() action) async {
    if (_blocked) return;

    setState(() => _photoError = null);
    try {
      if (!mounted) return;
      await action();
      if (mounted && _previewError != null) {
        setState(() => _photoError = _previewError);
      }
    } on LiveCameraException catch (error) {
      if (mounted) setState(() => _photoError = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _photoError = 'This camera control is unavailable. You can still take or choose a photo.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final large = MediaQuery.textScalerOf(context).scale(14) > 21;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop =
                constraints.maxWidth >= 800 ||
                (constraints.maxWidth >= 650 && constraints.maxHeight < 500);
            return Padding(
              padding: EdgeInsets.fromLTRB(
                desktop ? 24 : 0,
                desktop ? 16 : 0,
                desktop ? 24 : 0,
                12,
              ),
              child: desktop
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLowest.withValues(
                          alpha: .9,
                        ),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(
                          constraints.maxHeight < 500 ? 16 : 28,
                        ),
                        child: Column(
                          children: [
                            _header(
                              desktop: true,
                              compact: constraints.maxHeight < 500,
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(flex: 7, child: _preview()),
                                  const SizedBox(width: 28),
                                  Expanded(
                                    flex: 5,
                                    child: Center(
                                      child: SingleChildScrollView(
                                        child: _controls(
                                          desktop: true,
                                          large: large,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : large || constraints.maxHeight < 460
                  ? SingleChildScrollView(
                      child: Column(
                        children: [
                          _header(desktop: false),
                          SizedBox(height: 300, child: _mobilePreview()),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                            child: _controls(desktop: false, large: large),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        _header(
                          desktop: false,
                          compact: constraints.maxHeight < 620,
                        ),
                        Expanded(child: _mobilePreview()),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: _controls(desktop: false, large: false),
                        ),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _header({required bool desktop, bool compact = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: desktop ? 0 : 6,
        vertical: compact ? 4 : 6,
      ),
      child: Column(
        crossAxisAlignment: desktop
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Text(
            'Scan Label',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize: desktop && !compact
                  ? 38
                  : compact
                  ? 26
                  : 30,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Capture the front, back or barcode',
            textAlign: desktop ? TextAlign.start : TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: compact ? 12 : 14,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _mobilePreview() => LayoutBuilder(
    builder: (context, constraints) => Padding(
      padding: EdgeInsets.symmetric(
        horizontal: (constraints.maxWidth * .05).clamp(16, 40),
      ),
      child: _preview(),
    ),
  );

  Widget _controls({required bool desktop, required bool large}) {
    final theme = Theme.of(context);
    final hasPhoto = _photos[_mode] != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _modeCard(
                      0,
                      'Front',
                      'document-text',
                      desktop,
                      large,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: _modeCard(
                      1,
                      'Back',
                      'document-text',
                      desktop,
                      large,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: _modeCard(2, 'Barcode', 'barcode', desktop, large),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: desktop ? 28 : 12),
        if (_photoError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Semantics(
              liveRegion: true,
              child: Text(_photoError!, style: theme.textTheme.bodySmall),
            ),
          ),
        FilledButton.icon(
          key: const Key('scan-primary'),
          onPressed: _primaryAction,
          style: FilledButton.styleFrom(
            minimumSize: Size.fromHeight(desktop ? 64 : 52),
            backgroundColor: theme.brightness == Brightness.dark
                ? const Color(0xff00e8c1)
                : theme.colorScheme.primary,
            foregroundColor: theme.brightness == Brightness.dark
                ? const Color(0xff062923)
                : theme.colorScheme.onPrimary,
            shape: const StadiumBorder(),
          ),
          icon: Icon(
            hasPhoto ? Icons.fact_check_outlined : Icons.camera_alt_outlined,
          ),
          label: Text(_primaryLabel, textAlign: TextAlign.center),
        ),
        if (desktop) ...[
          const SizedBox(height: 20),
          const Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('or'),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 20),
        ],
        if (!_reading) ...[
          SizedBox(height: desktop ? 0 : 10),
          OutlinedButton.icon(
            key: const Key('scan-gallery'),
            onPressed: _blocked ? null : _gallery,
            style: OutlinedButton.styleFrom(
              minimumSize: Size.fromHeight(desktop ? 60 : 48),
              side: BorderSide(color: theme.colorScheme.primary),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            icon: const FeatureIcon('gallery', size: 22),
            label: const Text('Choose Photo'),
          ),
        ],
        if (_reading)
          TextButton(
            onPressed: _stopReading,
            child: const Text('Stop reading'),
          ),
      ],
    );
  }

  bool get _canToggleTorch =>
      _barcodeMode ? _barcodeScanner.canToggleTorch : _camera.canToggleTorch;
  bool get _canSwitchCamera =>
      _barcodeMode ? _barcodeScanner.canSwitchCamera : _camera.canSwitchCamera;
  bool get _torchOn => _barcodeMode ? _barcodeScanner.torchOn : _camera.torchOn;

  Widget _torchButton() => IconButton.filledTonal(
    tooltip: _torchOn ? 'Turn flash off' : 'Turn flash on',
    onPressed: _blocked || !_canToggleTorch
        ? null
        : () => _cameraControl(
            _barcodeMode ? _barcodeScanner.toggleTorch : _camera.toggleTorch,
          ),
    icon: Icon(_torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded),
  );

  Widget _switchCameraButton() => IconButton.filledTonal(
    tooltip: 'Switch camera',
    onPressed: _blocked || !_canSwitchCamera
        ? null
        : () => _cameraControl(
            _barcodeMode ? _barcodeScanner.switchCamera : _camera.switchCamera,
          ),
    icon: const Icon(Icons.flip_camera_ios_outlined),
  );

  Widget _preview() {
    final theme = Theme.of(context);
    final photo = _photos[_mode];
    return LayoutBuilder(
      builder: (context, constraints) {
        _previewSize = constraints.biggest;
        return ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Container(
            key: const Key('scan-preview'),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xff293338),
                  Color(0xff11191d),
                  Color(0xff17221f),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_usesBarcodeSdk)
                  Offstage(
                    offstage:
                        !_barcodeMode ||
                        photo != null ||
                        _detectedBarcode != null,
                    child: _barcodeScanner.buildPreview(),
                  ),
                if (photo != null)
                  Image.memory(
                    photo,
                    fit: BoxFit.contain,
                    semanticLabel: switch (_mode) {
                      0 => 'Captured front label',
                      1 => 'Captured back label',
                      _ => 'Captured barcode',
                    },
                    errorBuilder: (_, _, _) =>
                        const Center(child: Text('Photo unavailable')),
                  )
                else if (!_barcodeMode && _camera.ready)
                  _camera.buildPreview(),
                if (photo == null && !_previewReady)
                  _detectedBarcode == null ? _cameraStatus() : _barcodeStatus(),
                if (_reading && photo != null)
                  Positioned.fill(
                    child: ScanProcessingOverlay(
                      barcode: _mode == 2,
                      active: _foreground,
                    ),
                  ),
                if (photo == null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: CustomPaint(
                          painter: _ScanFramePainter(const Color(0xff32f1c5)),
                        ),
                      ),
                    ),
                  ),
                if (_previewReady && photo == null) ...[
                  const Center(
                    child: IgnorePointer(
                      child: SizedBox.square(
                        dimension: 36,
                        child: CustomPaint(
                          painter: _ScanFramePainter(Color(0xffa5b7b1)),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_canToggleTorch) _torchButton(),
                        if (_canSwitchCamera) ...[
                          const SizedBox(width: 8),
                          _switchCameraButton(),
                        ],
                      ],
                    ),
                  ),
                ],
                if (photo != null)
                  if (_sizes[_mode] != null && _result != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: LabelHighlightsPainter(
                            (_result!.label?.regions ?? <ExtractedRegion>[])
                                .where(
                                  (r) =>
                                      r.slot ==
                                      const ['front', 'back', 'barcode'][_mode],
                                )
                                .toList(),
                            _sizes[_mode]!,
                            barcodePoints: _result!.barcodeSlot == _mode
                                ? _result!.barcodePoints
                                : const [],
                          ),
                        ),
                      ),
                    ),
                if (photo != null)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: FilledButton.tonalIcon(
                      onPressed: _reading
                          ? null
                          : () {
                              _photoRevision++;
                              _reader.cancel();
                              setState(() {
                                _photos.remove(_mode);
                                _sizes.remove(_mode);
                                _result = null;
                              });
                              unawaited(_syncCamera());
                            },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retake'),
                    ),
                  ),
                if (_previewReady && photo == null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Text(
                      _mode == 2
                          ? 'Hold the barcode steady. Scanning automatically.'
                          : _mode == 0
                          ? 'Keep the front label in the frame'
                          : 'Keep nutrition and ingredients in the frame',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        backgroundColor: const Color(0x99000000),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _cameraStatus() => LayoutBuilder(
    builder: (context, constraints) {
      if (_previewBusy) {
        return Center(
          child: Semantics(
            label: 'Opening camera',
            child: const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(color: Color(0xff70efba)),
            ),
          ),
        );
      }
      final compact =
          constraints.maxHeight < 260 ||
          MediaQuery.textScalerOf(context).scale(14) > 21;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!compact) ...[
                const Icon(
                  Icons.videocam_off_outlined,
                  size: 32,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                Text(
                  _previewError ?? 'Camera preview is unavailable.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
              TextButton(
                onPressed: _working
                    ? null
                    : () {
                        _detectedBarcode = null;
                        unawaited(_syncCamera());
                      },
                child: const Text(
                  'Retry Camera',
                  style: TextStyle(color: Color(0xff70efba)),
                ),
              ),
              if (compact)
                TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Camera access'),
                      content: Text(
                        _previewError ?? 'Camera preview is unavailable. Retry or choose a photo.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                  child: const Text(
                    'Camera help',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );

  Widget _barcodeStatus() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _reading ? Icons.search_rounded : Icons.check_circle_outline,
            color: const Color(0xff32f1c5),
            size: 36,
          ),
          const SizedBox(height: 12),
          Text(
            _reading ? 'Finding product…' : 'Barcode found',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            _detectedBarcode!,
            style: const TextStyle(color: Color(0xffb7cbc5)),
          ),
          if (!_reading)
            TextButton(
              onPressed: () {
                _photoRevision++;
                setState(() {
                  _detectedBarcode = null;
                  _result = null;
                  _photoError = null;
                });
                unawaited(_syncCamera());
              },
              child: const Text(
                'Scan another',
                style: TextStyle(color: Color(0xff32f1c5)),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _modeCard(
    int index,
    String title,
    String icon,
    bool desktop,
    bool large,
  ) {
    final theme = Theme.of(context);
    final selected = _mode == index;
    final hasPhoto = _photos[index] != null;
    final stack = desktop || large;
    final label = Text(
      title,
      textAlign: TextAlign.center,
      style: theme.textTheme.labelLarge?.copyWith(fontSize: desktop ? 16 : 13),
    );
    final symbol = FeatureIcon(icon, size: desktop ? 28 : 20);
    return Semantics(
      selected: selected,
      child: Material(
        color: selected
            ? theme.colorScheme.primaryContainer
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(desktop ? 22 : 24),
          side: BorderSide(
            color: selected ? theme.colorScheme.primary : Colors.transparent,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('scan-mode-$index'),
          onTap: _blocked ? null : () => _selectMode(index),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 6,
              vertical: desktop ? 20 : 13,
            ),
            child: stack
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      symbol,
                      const SizedBox(height: 6),
                      label,
                      if (hasPhoto)
                        const Icon(Icons.check_circle_rounded, size: 16),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      symbol,
                      const SizedBox(width: 5),
                      Flexible(child: label),
                      if (hasPhoto)
                        const Padding(
                          padding: EdgeInsets.only(left: 3),
                          child: Icon(Icons.check_circle_rounded, size: 12),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

Rect labelHighlightRect(Size viewport, Size image, Rect normalized) {
  final fit = applyBoxFit(BoxFit.contain, image, viewport);
  final destination = Alignment.center.inscribe(
    fit.destination,
    Offset.zero & viewport,
  );
  return Rect.fromLTRB(
    destination.left + normalized.left * destination.width,
    destination.top + normalized.top * destination.height,
    destination.left + normalized.right * destination.width,
    destination.top + normalized.bottom * destination.height,
  );
}

class LabelHighlightsPainter extends CustomPainter {
  const LabelHighlightsPainter(
    this.regions,
    this.imageSize, {
    this.barcodePoints = const [],
  });
  final List<ExtractedRegion> regions;
  final Size imageSize;
  final List<Offset> barcodePoints;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 20 || size.height < 30) return;
    final imageRect = labelHighlightRect(
      size,
      imageSize,
      const Rect.fromLTWH(0, 0, 1, 1),
    );
    final anchors = barcodePoints
        .map(
          (point) => Offset(
            imageRect.left + point.dx * imageRect.width,
            imageRect.top + point.dy * imageRect.height,
          ),
        )
        .toList();
    final barcodePaint = Paint()
      ..color = const Color(0xff70efba)
      ..strokeWidth = 3;
    for (var i = 0; i < anchors.length; i++) {
      canvas.drawCircle(anchors[i], 4, barcodePaint);
      if (i > 0) canvas.drawLine(anchors[i - 1], anchors[i], barcodePaint);
    }
    final usedLabels = <Rect>[];
    for (final region in regions) {
      final rect = labelHighlightRect(size, imageSize, region.box);
      final color = switch (region.label) {
        'allergen' => const Color(0xffffa5b0),
        'nutrition' => const Color(0xffffd46c),
        'barcode' => const Color(0xff79e5f1),
        _ => const Color(0xff79f1c3),
      };
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        Paint()..color = color.withValues(alpha: .12),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
      final label = switch (region.label) {
        'nutrition' => 'Nutrients',
        'ingredients' => 'Ingredients',
        'claim' => 'Front claim',
        'allergen' => 'Allergen text',
        'barcode' => 'Barcode',
        _ => 'Product',
      };
      final text = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Color(0xff073f31),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: size.width - 16);
      final labelWidth = text.width + 12;
      final labelHeight = text.height + 8;
      final rightSpace = size.width - rect.right;
      final side = rightSpace > labelWidth + 16;
      final left = (side ? rect.right + 12 : rect.left).clamp(
        4.0,
        (size.width - text.width - 12).clamp(4.0, size.width),
      );
      var top =
          (side ? rect.center.dy - labelHeight / 2 : rect.top - labelHeight - 4)
              .clamp(4.0, size.height - text.height - 8);
      var callout = Rect.fromLTWH(left, top, labelWidth, labelHeight);
      for (
        var attempt = 0;
        attempt < 8 && usedLabels.any((old) => old.overlaps(callout));
        attempt++
      ) {
        top = (top + labelHeight + 4).clamp(4.0, size.height - labelHeight - 4);
        callout = Rect.fromLTWH(left, top, labelWidth, labelHeight);
      }
      usedLabels.add(callout);
      if (side) {
        canvas.drawLine(
          rect.centerRight,
          callout.centerLeft,
          Paint()
            ..color = color
            ..strokeWidth = 2,
        );
        canvas.drawCircle(rect.centerRight, 3, Paint()..color = color);
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(callout, const Radius.circular(4)),
        Paint()..color = color,
      );
      text.paint(canvas, Offset(left + 6, top + 4));
      text.dispose();
    }
  }

  @override
  bool shouldRepaint(LabelHighlightsPainter oldDelegate) =>
      oldDelegate.regions != regions ||
      oldDelegate.imageSize != imageSize ||
      oldDelegate.barcodePoints != barcodePoints;
}

class _ScanFramePainter extends CustomPainter {
  const _ScanFramePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final length = size.shortestSide < 60 ? 11.0 : 30.0;
    final radius = size.shortestSide < 60 ? 4.0 : 12.0;
    for (final corner in [
      (0.0, 0.0, 1.0, 1.0),
      (size.width, 0.0, -1.0, 1.0),
      (0.0, size.height, 1.0, -1.0),
      (size.width, size.height, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(corner.$1, corner.$2 + length * corner.$4)
          ..lineTo(corner.$1, corner.$2 + radius * corner.$4)
          ..quadraticBezierTo(
            corner.$1,
            corner.$2,
            corner.$1 + radius * corner.$3,
            corner.$2,
          )
          ..lineTo(corner.$1 + length * corner.$3, corner.$2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ScanFramePainter oldDelegate) =>
      color != oldDelegate.color;
}
