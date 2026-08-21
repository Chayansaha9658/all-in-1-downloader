import 'package:flutter/services.dart';

/// Talks to native Android code (via MethodChannel) to draw and control the
/// floating "video detected" bubble. No-ops safely on non-Android platforms.
class OverlayService {
  static const _channel = MethodChannel('all_in_1_downloader/overlay');

  static Future<bool> hasPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasOverlayPermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (_) {}
  }

  static Future<void> showBubble() async {
    try {
      await _channel.invokeMethod('showBubble');
    } catch (_) {}
  }

  static Future<void> hideBubble() async {
    try {
      await _channel.invokeMethod('hideBubble');
    } catch (_) {}
  }

  /// Registers a callback invoked when the user taps the native bubble.
  static void setBubbleTapHandler(void Function() onTap) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'bubbleTapped') {
        onTap();
      }
    });
  }
}
