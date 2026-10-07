import 'dart:typed_data';

class LocalOcrFailure implements Exception {
  const LocalOcrFailure(this.message);
  final String message;
}

/// Implementations read session bytes locally; no API, storage or account access.
abstract interface class LocalOcrEngine {
  Future<String> recognize(
    Uint8List bytes,
    String language,
    void Function(double?) onProgress,
  );
  void cancel();
  void dispose();
}
