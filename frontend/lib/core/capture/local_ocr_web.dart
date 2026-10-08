import 'dart:js_interop';
import 'dart:typed_data';

import 'local_ocr_engine.dart';

@JS('unlabelOcr.recognize')
external JSPromise<JSString> _recognize(
  JSUint8Array bytes,
  JSString language,
  JSFunction progress,
);
@JS('unlabelOcr.cancel')
external void _cancel();

LocalOcrEngine createLocalOcrEngine() => _WebEngine();

class _WebEngine implements LocalOcrEngine {
  @override
  Future<String> recognize(
    Uint8List bytes,
    String language,
    void Function(double?) onProgress,
  ) async {
    try {
      final text = await _recognize(
        bytes.toJS,
        language.toJS,
        ((JSNumber? value) => onProgress(value?.toDartDouble)).toJS,
      ).toDart;
      return text.toDart;
    } catch (_) {
      throw const LocalOcrFailure(
        'Text reading could not finish. Retake the photo or use automatic AI reading.',
      );
    }
  }

  @override
  void cancel() {
    try {
      _cancel();
    } catch (_) {
      // Retaking a photo remains available if the bridge is unavailable.
    }
  }

  @override
  void dispose() => cancel();
}
