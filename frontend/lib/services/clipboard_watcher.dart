import 'package:flutter/services.dart';

/// Simple regex-based check for whether a piece of text looks like a
/// video/audio link this app could handle. Kept intentionally broad (any
/// http(s) link) since the backend's generic extractor already tries most
/// sites -- narrowing this down would only cause missed detections.
class ClipboardWatcher {
  static final _urlPattern = RegExp(r'^https?://\S+$', caseSensitive: false);

  static String? _lastChecked;

  /// Returns the clipboard text if it looks like a fresh, unseen link,
  /// otherwise null. Call this only while the app is in the foreground --
  /// Android blocks clipboard reads from background/inactive apps.
  static Future<String?> checkForVideoLink() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return null;
    if (text == _lastChecked) return null;
    if (!_urlPattern.hasMatch(text)) return null;
    _lastChecked = text;
    return text;
  }

  static void reset() {
    _lastChecked = null;
  }
}
