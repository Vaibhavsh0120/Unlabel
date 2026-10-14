import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/accounts/account_auth.dart';
import '../../../core/accounts/profile_media.dart';
import '../../../core/capture/photo_decode.dart';
import '../../../core/models/app_failure.dart';

class ProfileMediaScope extends InheritedNotifier<ProfileMediaController> {
  const ProfileMediaScope({
    super.key,
    required ProfileMediaController controller,
    required super.child,
  }) : super(notifier: controller);

  static ProfileMediaController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProfileMediaScope>()?.notifier;
}

/// Uses the selected private photo first. An unset gender uses the project's
/// original avatar artwork without inferring or writing a gender choice.
class AccountAvatar extends StatelessWidget {
  const AccountAvatar({
    super.key,
    this.media,
    this.identity,
    this.displayName,
    this.preview,
    this.size = 48,
  });

  final ProfileMediaController? media;
  final AccountIdentity? identity;
  final String? displayName;
  final ProfileMedia? preview;
  final double size;

  @override
  Widget build(BuildContext context) {
    final controller = media ?? ProfileMediaScope.maybeOf(context);
    if (controller == null) return _content(context, null);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _content(context, controller),
    );
  }

  Widget _content(BuildContext context, ProfileMediaController? controller) {
    final value = preview ?? controller?.value;
    final owner = controller?.identity ?? identity;
    final safePhoto = owner?.hasGoogle == true
        ? safeGooglePhotoUrl(owner?.photoUrl)
        : null;
    final source = value?.source ?? ProfileAvatarSource.automatic;
    final custom = value?.avatarPng;
    Widget fallback() {
      final gender = value?.gender ?? ProfileGender.unspecified;
      return Image.asset(
        gender == ProfileGender.female
            ? 'assets/artwork/profile-avatar-female.webp'
            : 'assets/artwork/profile-avatar.webp',
        fit: BoxFit.cover,
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
        errorBuilder: (context, error, stack) => _initials(context, owner),
        excludeFromSemantics: true,
      );
    }

    final child = source == ProfileAvatarSource.custom && custom != null
        ? Image.memory(
            custom,
            fit: BoxFit.cover,
            gaplessPlayback: false,
            errorBuilder: (context, error, stack) => fallback(),
            excludeFromSemantics: true,
          )
        : source != ProfileAvatarSource.defaultAvatar && safePhoto != null
        ? Image.network(
            safePhoto,
            fit: BoxFit.cover,
            gaplessPlayback: false,
            errorBuilder: (context, error, stack) => fallback(),
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : fallback(),
            excludeFromSemantics: true,
          )
        : fallback();
    return Semantics(
      label: 'Profile picture',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: ClipRRect(
          key: const ValueKey('profile-avatar-square'),
          borderRadius: BorderRadius.circular(math.min(12, size * .12)),
          child: child,
        ),
      ),
    );
  }

  Widget _initials(BuildContext context, AccountIdentity? owner) {
    final name = displayName?.trim() ?? owner?.displayName?.trim() ?? '';
    final words = name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    final initials = words.take(2).map((part) => part.characters.first).join();
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.primaryContainer,
      child: Center(
        child: initials.isEmpty
            ? Icon(
                Icons.person_outline,
                size: size * .55,
                color: colors.primary,
              )
            : Text(
                initials.toUpperCase(),
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontSize: size * .34,
                  fontWeight: FontWeight.w600,
                  color: colors.onPrimaryContainer,
                ),
              ),
      ),
    );
  }
}

/// Only the SDK's HTTPS Google profile host is used for provider photos.
String? safeGooglePhotoUrl(String? value) {
  if (value == null || value.length > 2048) return null;
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      (uri.hasPort && uri.port != 443) ||
      !(uri.host == 'googleusercontent.com' ||
          uri.host.endsWith('.googleusercontent.com'))) {
    return null;
  }
  return uri.toString();
}

class ProfilePhotoEditor extends StatefulWidget {
  const ProfilePhotoEditor({
    super.key,
    required this.media,
    this.identity,
    this.pickPhoto,
    this.cropOnly = false,
    this.startWithGallery = false,
  });

  final ProfileMediaController media;
  final AccountIdentity? identity;
  final Future<Uint8List?> Function()? pickPhoto;
  final bool cropOnly, startWithGallery;

  static Future<Uint8List?> crop(
    BuildContext context, {
    required ProfileMediaController media,
    AccountIdentity? identity,
    Future<Uint8List?> Function()? pickPhoto,
  }) => showDialog<Uint8List>(
    context: context,
    barrierDismissible: false,
    animationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (_) => ProfilePhotoEditor(
      media: media,
      identity: identity,
      pickPhoto: pickPhoto,
      cropOnly: true,
      startWithGallery: true,
    ),
  );

  static Future<void> show(
    BuildContext context, {
    required ProfileMediaController media,
    AccountIdentity? identity,
  }) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    animationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (_) => ProfilePhotoEditor(media: media, identity: identity),
  );

  @override
  State<ProfilePhotoEditor> createState() => _ProfilePhotoEditorState();
}

class _ProfilePhotoEditorState extends State<ProfilePhotoEditor> {
  ui.Image? _image;
  Offset _center = const Offset(.5, .5);
  double _zoom = 1;
  bool _working = false;
  String? _error;
  late final String? _owner = widget.media.ownerUid;

  @override
  void initState() {
    super.initState();
    widget.media.addListener(_mediaChanged);
    if (widget.startWithGallery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_pick());
      });
    }
  }

  void _mediaChanged() {
    if (!mounted) return;
    if (widget.media.ownerUid != _owner) {
      if (ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop();
      }
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.media.removeListener(_mediaChanged);
    _image?.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() {
      _working = true;
      _error = null;
    });
    ui.Image? decoded;
    try {
      Uint8List? bytes;
      if (widget.pickPhoto != null) {
        bytes = await widget.pickPhoto!();
      } else {
        final file = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          requestFullMetadata: false,
        );
        if (file != null) {
          if (await file.length() > 12 * 1024 * 1024) throw _invalidPhoto;
          bytes = await file.readAsBytes();
        }
      }
      if (bytes == null) return;
      // Header and upright decoder dimensions are both checked before painting.
      // Source bytes stay transient and are never passed to Firestore.
      decoded = (await decodePhoto(bytes, maxEdge: 1200)).image;
      if (!mounted || widget.media.ownerUid != _owner) return;
      _image?.dispose();
      _image = decoded;
      decoded = null;
      _center = const Offset(.5, .5);
      _zoom = 1;
    } catch (_) {
      if (mounted) _error = _invalidPhoto.userMessage;
    } finally {
      decoded?.dispose();
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _save() async {
    final image = _image;
    if (image == null) return;
    if (widget.cropOnly) {
      setState(() {
        _working = true;
        _error = null;
      });
      try {
        final png = await encodeAvatarCrop(image, center: _center, zoom: _zoom);
        if (mounted && widget.media.ownerUid == _owner) {
          Navigator.pop(context, png);
        }
      } catch (_) {
        if (mounted) {
          setState(
            () => _error = 'The photo could not be cropped. Try another image.',
          );
        }
      } finally {
        if (mounted) setState(() => _working = false);
      }
      return;
    }
    await _perform(() async {
      final png = await encodeAvatarCrop(image, center: _center, zoom: _zoom);
      if (!mounted || widget.media.ownerUid != _owner) return;
      await widget.media.saveCustomPhoto(png);
    });
  }

  Future<void> _perform(Future<void> Function() action) async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.of(context).pop();
    } on AppFailure catch (failure) {
      if (mounted) setState(() => _error = failure.userMessage);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'The photo could not be saved. Try another image.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final busy = _working || widget.media.busy;
    final owner = widget.media.identity ?? widget.identity;
    final googlePhoto = owner?.hasGoogle == true
        ? safeGooglePhotoUrl(owner?.photoUrl)
        : null;
    return PopScope(
      canPop: !_working,
      child: Dialog(
        key: const ValueKey('profile-photo-window'),
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: MediaQuery.sizeOf(context).height * .88,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ColoredBox(
                color: colors.primaryContainer.withValues(alpha: .28),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 12, 16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_circle_outlined,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.cropOnly
                              ? 'Crop profile photo'
                              : 'Profile photo',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close profile photo',
                        onPressed: _working
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_image == null)
                        AccountAvatar(
                          media: widget.media,
                          identity: owner,
                          size: 144,
                        )
                      else ...[
                        Text(
                          'Drag to position your photo.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final edge = math.min(288.0, constraints.maxWidth);
                            return Semantics(
                              label: 'Profile photo crop preview',
                              image: true,
                              child: GestureDetector(
                                onPanUpdate: busy
                                    ? null
                                    : (details) => setState(() {
                                        final crop = avatarCropRect(
                                          _image!,
                                          center: _center,
                                          zoom: _zoom,
                                        );
                                        _center = clampAvatarCenter(
                                          _image!,
                                          Offset(
                                            _center.dx -
                                                details.delta.dx *
                                                    crop.width /
                                                    edge /
                                                    _image!.width,
                                            _center.dy -
                                                details.delta.dy *
                                                    crop.height /
                                                    edge /
                                                    _image!.height,
                                          ),
                                          _zoom,
                                        );
                                      }),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CustomPaint(
                                    size: Size.square(edge),
                                    painter: _AvatarCropPainter(
                                      _image!,
                                      _center,
                                      _zoom,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.zoom_out, size: 20),
                            Expanded(
                              child: Slider(
                                key: const ValueKey('profile-photo-zoom'),
                                label: '${_zoom.toStringAsFixed(1)}× zoom',
                                min: 1,
                                max: 4,
                                value: _zoom,
                                onChanged: busy
                                    ? null
                                    : (zoom) => setState(() {
                                        _zoom = zoom;
                                        _center = clampAvatarCenter(
                                          _image!,
                                          _center,
                                          zoom,
                                        );
                                      }),
                              ),
                            ),
                            const Icon(Icons.zoom_in, size: 20),
                          ],
                        ),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          children: [
                            for (final move in [
                              (
                                'Move crop left',
                                Icons.arrow_back,
                                const Offset(-.05, 0),
                              ),
                              (
                                'Move crop up',
                                Icons.arrow_upward,
                                const Offset(0, -.05),
                              ),
                              (
                                'Move crop down',
                                Icons.arrow_downward,
                                const Offset(0, .05),
                              ),
                              (
                                'Move crop right',
                                Icons.arrow_forward,
                                const Offset(.05, 0),
                              ),
                            ])
                              IconButton(
                                tooltip: move.$1,
                                icon: Icon(move.$2, size: 20),
                                onPressed: busy
                                    ? null
                                    : () => setState(() {
                                        _center = clampAvatarCenter(
                                          _image!,
                                          _center + move.$3,
                                          _zoom,
                                        );
                                      }),
                              ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton.icon(
                              onPressed: busy
                                  ? null
                                  : () => setState(() {
                                      _center = const Offset(.5, .5);
                                      _zoom = 1;
                                    }),
                              icon: const Icon(
                                Icons.center_focus_strong,
                                size: 18,
                              ),
                              label: const Text('Center photo'),
                            ),
                            TextButton(
                              onPressed: busy ? null : _pick,
                              child: const Text('Choose another'),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      if (_image == null) ...[
                        if (owner != null)
                          FilledButton.tonalIcon(
                            onPressed: busy ? null : _pick,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Choose a photo'),
                          )
                        else
                          const Text('Sign in to save a custom profile photo.'),
                        const SizedBox(height: 12),
                        if (!widget.cropOnly)
                          PopupMenuButton<ProfileAvatarSource>(
                            tooltip: 'Photo options',
                            enabled: !busy,
                            onSelected: (source) => _perform(switch (source) {
                              ProfileAvatarSource.google =>
                                widget.media.useGooglePhoto,
                              ProfileAvatarSource.defaultAvatar =>
                                widget.media.useDefaultAvatar,
                              _ => widget.media.removeCustomPhoto,
                            }),
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: ProfileAvatarSource.defaultAvatar,
                                child: Text('Use default avatar'),
                              ),
                              if (googlePhoto != null)
                                const PopupMenuItem(
                                  value: ProfileAvatarSource.google,
                                  child: Text('Use Google photo'),
                                ),
                              if (widget.media.value.avatarPng != null)
                                const PopupMenuItem(
                                  value: ProfileAvatarSource.automatic,
                                  child: Text('Remove custom photo'),
                                ),
                            ],
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(child: Text('Photo options')),
                                  SizedBox(width: 8),
                                  Icon(Icons.expand_more, size: 20),
                                ],
                              ),
                            ),
                          ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        owner == null
                            ? 'Your gender choice controls the default avatar.'
                            : widget.cropOnly
                            ? 'Confirm this square crop, then save your profile.'
                            : 'Only the cropped thumbnail is saved privately to your account.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            style: TextStyle(color: colors.error),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: _working
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    if (_image != null)
                      FilledButton.icon(
                        key: const ValueKey('profile-photo-save'),
                        onPressed: busy ? null : _save,
                        icon: busy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check, size: 20),
                        label: Text(
                          widget.cropOnly ? 'Use this crop' : 'Save photo',
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _invalidPhoto = AppFailure(
    'invalid_photo',
    'Choose a JPEG, PNG or WebP photo smaller than 12 MB.',
  );
}

Offset clampAvatarCenter(ui.Image image, Offset center, double zoom) {
  final edge = math.min(image.width, image.height) / zoom.clamp(1, 4);
  final x = edge / 2 / image.width;
  final y = edge / 2 / image.height;
  return Offset(center.dx.clamp(x, 1 - x), center.dy.clamp(y, 1 - y));
}

Rect avatarCropRect(
  ui.Image image, {
  Offset center = const Offset(.5, .5),
  double zoom = 1,
}) {
  final clamped = clampAvatarCenter(image, center, zoom);
  final edge = math.min(image.width, image.height) / zoom.clamp(1, 4);
  return Rect.fromCenter(
    center: Offset(clamped.dx * image.width, clamped.dy * image.height),
    width: edge,
    height: edge,
  );
}

/// Rasterizing only the chosen region strips EXIF, GPS and the original encoded
/// file. Never persist the original source image or a data URL in Firebase Auth.
Future<Uint8List> encodeAvatarCrop(
  ui.Image image, {
  Offset center = const Offset(.5, .5),
  double zoom = 1,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImageRect(
    image,
    avatarCropRect(image, center: center, zoom: zoom),
    const Rect.fromLTWH(0, 0, 192, 192),
    Paint()..filterQuality = FilterQuality.medium,
  );
  final picture = recorder.endRecording();
  final thumbnail = await picture.toImage(
    ProfileMedia.avatarEdge,
    ProfileMedia.avatarEdge,
  );
  picture.dispose();
  try {
    final data = await thumbnail.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw const FormatException('Could not encode profile photo');
    }
    var bytes = data.buffer.asUint8List();
    if (bytes.length > ProfileMedia.maxAvatarBytes) {
      // No server compressor or Storage bucket is needed. Only unusually noisy
      // thumbnails need four-bit channel quantization to fit the private cap.
      final rgba = await thumbnail.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (rgba == null) throw const FormatException('Could not resize photo');
      final pixels = rgba.buffer.asUint8List();
      for (var index = 0; index < pixels.length; index++) {
        pixels[index] = ((pixels[index] + 8) ~/ 17).clamp(0, 15) * 17;
      }
      final decoded = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        pixels,
        ProfileMedia.avatarEdge,
        ProfileMedia.avatarEdge,
        ui.PixelFormat.rgba8888,
        decoded.complete,
      );
      final compressed = await decoded.future;
      try {
        final encoded = await compressed.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (encoded == null) {
          throw const FormatException('Could not encode photo');
        }
        bytes = encoded.buffer.asUint8List();
      } finally {
        compressed.dispose();
      }
    }
    ProfileMedia.validateAvatarPng(bytes);
    return bytes;
  } finally {
    thumbnail.dispose();
  }
}

class _AvatarCropPainter extends CustomPainter {
  _AvatarCropPainter(this.image, this.center, this.zoom);
  final ui.Image image;
  final Offset center;
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawImageRect(
    image,
    avatarCropRect(image, center: center, zoom: zoom),
    Offset.zero & size,
    Paint()..filterQuality = FilterQuality.medium,
  );

  @override
  bool shouldRepaint(_AvatarCropPainter old) =>
      old.image != image || old.center != center || old.zoom != zoom;
}
