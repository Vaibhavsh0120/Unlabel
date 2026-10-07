import 'dart:typed_data';

import 'local_ocr_engine.dart';

LocalOcrEngine createLocalOcrEngine() => _UnavailableEngine();

class _UnavailableEngine implements LocalOcrEngine {
  @override
  Future<String> recognize(
    Uint8List bytes,
    String language,
    void Function(double?) onProgress,
  ) async {
    throw const LocalOcrFailure(
      'Text reading is unavailable here. Enter the printed facts manually.',
    );
  }

  @override
  void cancel() {}
  @override
  void dispose() {}
}
