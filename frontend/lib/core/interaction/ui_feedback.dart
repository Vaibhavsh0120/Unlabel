import 'package:flutter/services.dart';

/// Feedback follows completed user actions; platform support is optional.
abstract final class UiFeedback {
  static Future<void> selection() => _play(HapticFeedback.selectionClick);
  static Future<void> confirmed() => _play(HapticFeedback.lightImpact);

  static Future<void> _play(Future<void> Function() action) async {
    try {
      await action();
    } on MissingPluginException {
      // Desktop/web platforms may not expose haptic hardware.
    } on PlatformException {
      // A feedback failure must never prevent the actual action.
    }
  }
}
