import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/capture/live_camera.dart';
import '../../../core/interaction/ui_feedback.dart';
import 'ui_components.dart';

class ScanLandingPage extends StatefulWidget {
  const ScanLandingPage({
    required this.onBarcode,
    required this.onEnterLabel,
    required this.onSearch,
    this.onBack,
    this.onReviewCapture,
    this.camera,
    this.pickPhoto,
    super.key,
  });
  final Future<void> Function() onBarcode, onEnterLabel, onSearch;
  final VoidCallback? onBack;
  final Future<void> Function(Map<int, Uint8List>)? onReviewCapture;
  final LiveCamera? camera;
  final Future<Uint8List?> Function()? pickPhoto;

  @override
  State<ScanLandingPage> createState() => _ScanLandingPageState();
}

class _ScanLandingPageState extends State<ScanLandingPage>
    with WidgetsBindingObserver {
  late final LiveCamera _camera = widget.camera ?? LiveCamera();
  final _photos = <int, Uint8List>{};
  int _mode = 0;
  bool _working = false, _routeOpen = false, _foreground = true;
  String? _photoError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _camera.addListener(_cameraChanged);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreGallery());
  }

  Future<void> _restoreGallery() async {
    if (!mounted) return;
    // Android may recreate the activity while its system photo picker is open.
    // Restore only that pending selection; photos remain in this route's memory.
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        widget.pickPhoto == null) {
      setState(() => _working = true);
      try {
        final response = await ImagePicker().retrieveLostData();
        if (!mounted) return;
        final files = response.files;
        if (files != null && files.isNotEmpty) {
          final bytes = await _readPhoto(files.first);
          if (!mounted) return;
          setState(() {
            _mode = 1;
            _photos[1] = bytes;
          });
        } else if (response.exception != null) {
          setState(
            () => _photoError =
                'The photo selection was interrupted. Choose the image again.',
          );
        }
      } catch (_) {
        if (mounted) {
          setState(
            () => _photoError = 'The photo selection could not be restored. Choose the image again.',
          );
        }
      } finally {
        if (mounted) setState(() => _working = false);
      }
    }
    if (mounted) unawaited(_syncCamera());
  }

  void _cameraChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _syncCamera() async {
    if (!mounted) return;
    if (_foreground && !_routeOpen && !_working && _photos[_mode] == null) {
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
    _routeOpen = true;
    await _camera.stop();
    if (!mounted) return;
    try {
      await open();
    } finally {
      _routeOpen = false;
      if (mounted) unawaited(_syncCamera());
    }
  }

  Future<void> _capture() async {
    if (_working || !_camera.ready) return;
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
      setState(() => _photos[_mode == 2 ? 1 : _mode] = bytes);
      if (_mode == 2) setState(() => _mode = 1);
      unawaited(UiFeedback.selection());
    } catch (_) {
      if (mounted) {
        setState(
          () => _photoError = 'Could not open that image. Choose another photo or enter the label manually.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _working = false);
        unawaited(_syncCamera());
      }
    }
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
    if (await file.length() > LiveCamera.maxCaptureBytes) {
      throw StateError('large_photo');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > LiveCamera.maxCaptureBytes) {
      throw StateError('invalid_photo');
    }
    return bytes;
  }

  void _selectMode(int mode) {
    if (_working || _mode == mode) return;
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
            tooltip: 'Choose label photo',
            onPressed: _working ? null : _gallery,
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
          onPressed: _working
              ? null
              : _mode == 2
              ? () => _route(widget.onBarcode)
              : hasPhoto
              ? () => _route(
                  () =>
                      widget.onReviewCapture?.call(Map.unmodifiable(_photos)) ??
                      widget.onEnterLabel(),
                )
              : _camera.ready
              ? _capture
              : () => _route(widget.onEnterLabel),
          icon: FeatureIcon(
            hasPhoto ? 'stars' : 'scanner',
            color: theme.colorScheme.onPrimary,
            size: 22,
          ),
          label: Text(
            _working
                ? 'Working…'
                : _mode == 2
                ? 'Enter barcode'
                : hasPhoto
                ? 'Review Label'
                : _camera.ready
                ? 'Take Photo'
                : 'Enter Label',
          ),
        ),
        TextButton(
          onPressed: _working ? null : _gallery,
          child: const Text('Use Gallery'),
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
              Positioned(
                right: 12,
                bottom: 12,
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    setState(() => _photos.remove(_mode));
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
                      ? 'Read the printed product code'
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
