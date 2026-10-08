import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/capture/live_camera.dart';
import '../../../core/capture/photo_decode.dart';
import '../../../core/capture/automatic_label_reader.dart';
import '../../../core/models/extracted_label.dart';
import '../../../core/models/app_failure.dart';
import '../../../core/interaction/ui_feedback.dart';
import 'ui_components.dart';

class ScanLandingPage extends StatefulWidget {
  const ScanLandingPage({
    required this.reader,
    required this.onResult,
    this.onBack,
    this.camera,
    this.pickPhoto,
    super.key,
  });
  final AutomaticLabelReader reader;
  final Future<void> Function(AutomaticScanResult, Uint8List?) onResult;
  final VoidCallback? onBack;
  final LiveCamera? camera;
  final Future<Uint8List?> Function()? pickPhoto;

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
  int _mode = 0;
  int _photoRevision = 0;
  bool _working = false, _routeOpen = false, _foreground = true;
  String? _photoError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _camera.addListener(_cameraChanged);
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
    if (_foreground &&
        !_routeOpen &&
        !_working &&
        !_reading &&
        _photos[_mode] == null) {
      await _camera.start();
    } else {
      await _camera.stop();
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
    await _camera.stop();
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
    if (_working || !_camera.ready) return;
    _photoRevision++;
    setState(() {
      _working = true;
      _photoError = null;
    });
    try {
      final bytes = await _camera.capture();
      if (!mounted) return;
      if (bytes.length > LiveCamera.maxCaptureBytes) {
        throw StateError('large_photo');
      }
      setState(() => _photos[_mode] = bytes);
      unawaited(_analyze());
      unawaited(UiFeedback.confirmed());
    } catch (_) {
      if (mounted) {
        setState(
          () => _photoError =
              'Could not capture this photo. Try again or use Gallery.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _working = false);
        unawaited(_syncCamera());
      }
    }
  }

  Future<void> _gallery() async {
    if (_working) return;
    _photoRevision++;
    setState(() {
      _working = true;
      _photoError = null;
    });
    await _camera.stop();
    try {
      if (!mounted) return;
      final bytes = widget.pickPhoto != null
          ? await widget.pickPhoto!()
          : await _pickPhoto();
      if (!mounted || bytes == null) return;
      if (bytes.isEmpty || bytes.length > LiveCamera.maxCaptureBytes) {
        throw StateError('large_photo');
      }
      setState(() => _photos[_mode] = bytes);
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
        setState(() => _working = false);
        unawaited(_syncCamera());
      }
    }
  }

  Future<bool> _allowCloud({bool force = false}) async {
    final preferences = await SharedPreferences.getInstance();
    final previous = preferences.getBool('unlabel.photo-reading-consent.v1');
    if (previous != null && !force) return previous;
    if (!mounted) return false;
    final allowed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Automatic photo reading'),
        content: const Text(
          'Send package photos to our backend and its Gemini or OpenAI service for automatic reading. Our backend does not save photos. Extracted product facts stay in private, temporary staging until checked. Google may use free-tier inputs to improve its services; provider retention terms apply. Only photograph the package. You can also read on this device.',
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
      await preferences.setBool('unlabel.photo-reading-consent.v1', allowed);
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
    await _camera.stop();
    try {
      for (final entry in _photos.entries.toList()) {
        final photo = await decodePhoto(entry.value, maxEdge: 1);
        _sizes[entry.key] = photo.originalSize;
        photo.image.dispose();
      }
      final result = await _reader.read(
        Map.unmodifiable(_photos),
        allowCloud: _allowCloud,
      );
      if (!mounted || revision != _photoRevision) return;
      setState(() {
        _result = result;
        if (!result.useful) {
          _photoError = result.barcode != null
              ? 'This barcode needs more information. Photograph the front and back of the package.'
              : 'No readable product information yet. Try a closer, clearer photo.';
        }
      });
      if (_mode == 2 &&
          (result.report != null || result.candidates.isNotEmpty)) {
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
      _photoError = 'Reading stopped. You can retry or retake the photo.';
    });
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
      _photoError = null;
    });
    unawaited(UiFeedback.selection());
    unawaited(_syncCamera());
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(14) > 21;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: large ? 88 : 60,
        centerTitle: true,
        title: const Text('Scan Label'),
        leading: IconButton(
          tooltip: 'Back to Home',
          onPressed: widget.onBack ?? () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            tooltip: 'Photo reading settings',
            onPressed: _working || _reading
                ? null
                : () async {
                    try {
                      await _allowCloud(force: true);
                    } catch (_) {
                      if (mounted) {
                        setState(
                          () => _photoError = 'Photo reading settings could not be saved. Try again.',
                        );
                      }
                    }
                  },
            icon: const Icon(Icons.tune_rounded),
          ),
          IconButton(
            tooltip: 'Choose label photo',
            onPressed: _working || _reading ? null : _gallery,
            icon: const FeatureIcon('gallery'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final landscape =
                constraints.maxWidth > 650 && constraints.maxHeight < 600;
            final controls = _controls(
              large: large,
              compact: constraints.maxHeight < 600 || large,
            );
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: landscape
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 3, child: _preview()),
                        const SizedBox(width: 20),
                        Expanded(flex: 2, child: Center(child: controls)),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _preview()),
                        const SizedBox(height: 12),
                        controls,
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _controls({required bool large, required bool compact}) {
    final theme = Theme.of(context);
    final hasPhoto = _photos[_mode] != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _modeCard(
                  0,
                  'Capture Front',
                  'Name & claims',
                  'document-text',
                  large,
                  compact,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _modeCard(
                  1,
                  'Capture Back',
                  'Nutrition & ingredients',
                  'document-text',
                  large,
                  compact,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _modeCard(
                  2,
                  'Barcode',
                  'Product code',
                  'barcode',
                  large,
                  compact,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_photoError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_photoError!, style: theme.textTheme.bodySmall),
          ),
        if (!compact)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const FeatureIcon('lightbulb', size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Capture ingredients and nutrition facts clearly.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        if (!compact) const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('scan-primary'),
          onPressed: _working || _reading
              ? null
              : _result?.useful == true
              ? () => _route(() => widget.onResult(_result!, _photos[0]))
              : hasPhoto
              ? _analyze
              : _camera.ready
              ? _capture
              : _gallery,
          icon: FeatureIcon(
            hasPhoto ? 'stars' : 'scanner',
            color: theme.colorScheme.onPrimary,
            size: 22,
          ),
          label: Text(
            _reading
                ? 'Reading your package…'
                : _working
                ? 'Working…'
                : _result?.useful == true
                ? 'View results'
                : hasPhoto
                ? 'Read photo again'
                : _camera.ready
                ? 'Take Photo'
                : 'Choose Photo',
          ),
        ),
        TextButton(
          onPressed: _working || _reading ? null : _gallery,
          child: const Text('Use Gallery'),
        ),
        if (_reading)
          TextButton(
            onPressed: _stopReading,
            child: const Text('Stop reading'),
          ),
      ],
    );
  }

  Widget _preview() {
    final theme = Theme.of(context);
    final photo = _photos[_mode];
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        key: const Key('scan-preview'),
        color: const Color(0xff17211e),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photo != null)
              Image.memory(
                photo,
                fit: BoxFit.contain,
                semanticLabel: _mode == 0
                    ? 'Captured front label'
                    : 'Captured back label',
                errorBuilder: (_, _, _) =>
                    const Center(child: Text('Photo unavailable')),
              )
            else if (_camera.ready)
              _camera.buildPreview()
            else
              _cameraStatus(),
            if (_camera.ready && photo == null)
              Positioned.fill(
                child: IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: CustomPaint(
                      painter: _ScanFramePainter(const Color(0xff70efba)),
                    ),
                  ),
                ),
              ),
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
            if (_camera.ready && photo == null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Text(
                  _mode == 2
                      ? 'Photograph the barcode for an instant lookup'
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
  }

  Widget _cameraStatus() => LayoutBuilder(
    builder: (context, constraints) {
      if (_camera.busy) {
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
                  _camera.error ?? 'Camera preview is unavailable.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
              TextButton(
                onPressed: _working ? null : () => _camera.start(),
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
                        _camera.error ?? 'Camera preview is unavailable. Retry or choose a photo.',
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

  Widget _modeCard(
    int index,
    String title,
    String subtitle,
    String icon,
    bool large,
    bool compact,
  ) {
    final theme = Theme.of(context);
    final selected = _mode == index;
    return Semantics(
      selected: selected,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        color: selected ? theme.colorScheme.primaryContainer : null,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('scan-mode-$index'),
          onTap: () => _selectMode(index),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 6,
              vertical: compact ? 8 : 12,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                FeatureIcon(icon, size: compact ? 22 : 26),
                const SizedBox(height: 6),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 12),
                ),
                if (!large && !compact) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                ],
                if (_photos[index] != null)
                  const Icon(Icons.check_circle_rounded, size: 18),
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
    const length = 24.0;
    for (final corner in [
      (0.0, 0.0, 1.0, 1.0),
      (size.width, 0.0, -1.0, 1.0),
      (0.0, size.height, 1.0, -1.0),
      (size.width, size.height, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(corner.$1, corner.$2 + length * corner.$4)
          ..lineTo(corner.$1, corner.$2)
          ..lineTo(corner.$1 + length * corner.$3, corner.$2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ScanFramePainter oldDelegate) =>
      color != oldDelegate.color;
}
