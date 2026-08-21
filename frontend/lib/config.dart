import 'dart:io';

String _defaultBaseUrl() {
  if (Platform.isAndroid) {
    // Android emulator's special alias for the host machine's localhost.
    return 'http://10.0.2.2:8000';
  }
  // macOS, iOS simulator, Windows, Linux, and physical iOS devices on the
  // same network as the backend should reach it via loopback or LAN IP.
  return 'http://127.0.0.1:8000';
}

final String apiBaseUrl =
    const String.fromEnvironment('API_BASE_URL', defaultValue: '').isNotEmpty
    ? const String.fromEnvironment('API_BASE_URL')
    : _defaultBaseUrl();
