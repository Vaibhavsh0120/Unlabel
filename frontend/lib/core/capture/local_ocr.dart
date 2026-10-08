import 'dart:async';
import 'dart:typed_data';

import 'photo_decode.dart';

import 'local_ocr_engine.dart';
import 'local_ocr_stub.dart'
    if (dart.library.io) 'local_ocr_native.dart'
    if (dart.library.js_interop) 'local_ocr_web.dart'
    as platform;

export 'local_ocr_engine.dart';

class LocalOcrReader {
  LocalOcrReader({
    LocalOcrEngine? engine,
    this.timeout = const Duration(seconds: 60),
  }) : _engine = engine ?? platform.createLocalOcrEngine();

  static const maxBytes = 12 * 1024 * 1024;
  static const maxPixels = 24 * 1000 * 1000;
  static const maxText = 12000;
  final LocalOcrEngine _engine;
  final Duration timeout;
  int _generation = 0;
  bool _busy = false, _disposed = false;

  Future<String> recognize(
    Uint8List bytes, {
    String language = 'en',
    void Function(double?)? onProgress,
  }) async {
    if (_disposed || _busy) {
      throw const LocalOcrFailure(
        'Wait for the current photo to finish, or stop text reading.',
      );
    }
    if (bytes.isEmpty ||
        bytes.length > maxBytes ||
        !const ['en', 'hi'].contains(language)) {
      throw const LocalOcrFailure('Choose a label photo smaller than 12 MB.');
    }
    _busy = true;
    final generation = ++_generation;
    bool current() => !_disposed && generation == _generation;
    try {
      await _validate(bytes).timeout(const Duration(seconds: 10));
      if (!current()) throw const LocalOcrFailure('Text reading stopped.');
      final text = await _engine
          .recognize(bytes, language, (value) {
            if (current()) onProgress?.call(value?.clamp(0, 1));
          })
          .timeout(timeout);
      if (!current()) throw const LocalOcrFailure('Text reading stopped.');
      if (text.length > maxText) {
        throw const LocalOcrFailure(
          'This photo has too much text. Crop to one label panel.',
        );
      }
      return text
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n')
          .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
          .trim();
    } on TimeoutException {
      cancel();
      throw const LocalOcrFailure(
        'Text reading took too long. Try a smaller photo or use automatic AI reading.',
      );
    } on LocalOcrFailure {
      rethrow;
    } catch (_) {
      throw const LocalOcrFailure(
        'This photo could not be read. Try a clearer photo or use automatic AI reading.',
      );
    } finally {
      if (current()) _busy = false;
    }
  }

  Future<void> _validate(Uint8List bytes) async {
    final photo = await decodePhoto(bytes, maxEdge: 1);
    photo.image.dispose();
  }

  void cancel() {
    _generation++;
    _busy = false;
    _engine.cancel();
  }

  void dispose() {
    _disposed = true;
    _generation++;
    _busy = false;
    _engine.dispose();
  }
}
