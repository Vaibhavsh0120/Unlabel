import 'package:flutter/services.dart';

import 'local_ocr_engine.dart';

LocalOcrEngine createLocalOcrEngine() => _NativeEngine();

class _NativeEngine implements LocalOcrEngine {
  static const _channel = MethodChannel('unlabel/local_ocr');
  @override
  Future<String> recognize(
    Uint8List bytes,
    String language,
    void Function(double?) onProgress,
  ) async {
    onProgress(null);
    try {
      return await _channel.invokeMethod<String>('recognize', {
            'bytes': bytes,
            'language': language,
          }) ??
          '';
    } on MissingPluginException {
      throw const LocalOcrFailure(
        'Text reading is unavailable on this device. Enter the printed facts manually.',
      );
    } on PlatformException catch (failure) {
      if (failure.code == 'unsupported_language') {
        throw const LocalOcrFailure(
          'Hindi text reading is unavailable on this device. Choose English or enter the printed Hindi text manually.',
        );
      }
      throw const LocalOcrFailure(
        'This photo could not be read. Try a clearer photo or enter the printed facts.',
      );
    }
  }

  @override
  void cancel() {
    _channel.invokeMethod<void>('cancel').catchError((Object _) {});
  }

  @override
  void dispose() => cancel();
}
