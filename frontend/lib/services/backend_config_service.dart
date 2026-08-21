import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import 'termux_bridge_service.dart';

/// Holds the backend base URL (e.g. http://192.168.0.42:8000) as a runtime,
/// user-editable, persisted setting -- instead of a value baked in at build
/// time. Whatever IP the backend happens to be running on today, entering it
/// once in Settings is enough; no rebuild needed when it changes later.
class BackendConfigService extends ChangeNotifier {
  BackendConfigService._();
  static final BackendConfigService instance = BackendConfigService._();

  static const _prefsKey = 'backend_base_url';
  static const _termuxCommandKey = 'termux_start_command';
  static const _termuxRepoUrlKey = 'termux_repo_url';
  static const _backendPort = 8000;

  // Starts from the compile-time smart default (config.dart), then gets
  // overridden by whatever was last saved, once load() completes.
  String _baseUrl = apiBaseUrl;
  String _termuxCommand = TermuxBridgeService.defaultCommand;
  String _termuxRepoUrl = '';
  bool _loaded = false;
  bool _hasCustomUrl = false;

  String get baseUrl => _baseUrl;
  String get termuxCommand => _termuxCommand;
  String get termuxRepoUrl => _termuxRepoUrl;
  bool get isLoaded => _loaded;
  // True once the person has actually set/confirmed a server address --
  // drives the "set your backend IP" hint on the home screen.
  bool get hasCustomUrl => _hasCustomUrl;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null && saved.trim().isNotEmpty) {
        _baseUrl = saved.trim();
        _hasCustomUrl = true;
      }
      final savedCommand = prefs.getString(_termuxCommandKey);
      if (savedCommand != null && savedCommand.trim().isNotEmpty) {
        _termuxCommand = savedCommand;
      }
      final savedRepoUrl = prefs.getString(_termuxRepoUrlKey);
      if (savedRepoUrl != null && savedRepoUrl.trim().isNotEmpty) {
        _termuxRepoUrl = savedRepoUrl.trim();
      }
    } catch (_) {
      // If prefs fail to load for any reason, just keep the compile-time
      // default rather than blocking app startup.
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setTermuxCommand(String command) async {
    final cleaned = command.trim();
    if (cleaned.isEmpty) return;
    _termuxCommand = cleaned;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_termuxCommandKey, cleaned);
  }

  Future<void> setTermuxRepoUrl(String url) async {
    final cleaned = url.trim();
    if (cleaned.isEmpty) return;
    _termuxRepoUrl = cleaned;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_termuxRepoUrlKey, cleaned);
  }

  Future<void> setBaseUrl(String input) async {
    final cleaned = _normalize(input);
    if (cleaned == null || cleaned.isEmpty) return;
    _baseUrl = cleaned;
    _hasCustomUrl = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, cleaned);
  }

  Future<void> resetToDefault() async {
    _baseUrl = apiBaseUrl;
    _hasCustomUrl = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  /// Accepts things like "192.168.0.42:8000", "192.168.0.42",
  /// "http://192.168.0.42:8000/" and normalizes to a clean base URL with
  /// no trailing slash and a default port of 8000 if none was given.
  String? _normalize(String input) {
    var text = input.trim();
    if (text.isEmpty) return null;

    if (!text.startsWith('http://') && !text.startsWith('https://')) {
      text = 'http://$text';
    }

    final uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty) return null;

    final port = uri.hasPort ? uri.port : _backendPort;
    return '${uri.scheme}://${uri.host}:$port';
  }

  /// Scans this device's local WiFi subnet(s) for something answering on
  /// [_backendPort] that looks like this app's FastAPI backend. Returns the
  /// matching "http://ip:port" if found, otherwise null. [onProgress]
  /// reports (checked, total) so the UI can show scan progress.
  Future<String?> autoDetect({
    void Function(int checked, int total)? onProgress,
  }) async {
    final prefixes = await _localSubnetPrefixes();
    if (prefixes.isEmpty) return null;

    final total = prefixes.length * 254;
    var checked = 0;
    const batchSize = 40;

    for (final prefix in prefixes) {
      final hosts = List.generate(254, (i) => '$prefix.${i + 1}');
      for (var start = 0; start < hosts.length; start += batchSize) {
        final end = math.min(start + batchSize, hosts.length);
        final batch = hosts.sublist(start, end);
        final results = await Future.wait(batch.map(_probe));
        checked += batch.length;
        onProgress?.call(checked, total);
        for (var i = 0; i < results.length; i++) {
          if (results[i]) {
            return 'http://${batch[i]}:$_backendPort';
          }
        }
      }
    }
    return null;
  }

  Future<List<String>> _localSubnetPrefixes() async {
    final prefixes = <String>{};
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final parts = addr.address.split('.');
          if (parts.length == 4) {
            prefixes.add('${parts[0]}.${parts[1]}.${parts[2]}');
          }
        }
      }
    } catch (_) {}
    return prefixes.toList();
  }

  /// True only if [host]:_backendPort is open AND answers like our FastAPI
  /// backend (so we don't mistake some other device on the network for it).
  Future<bool> _probe(String host) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        host,
        _backendPort,
        timeout: const Duration(milliseconds: 250),
      );
    } catch (_) {
      return false;
    } finally {
      socket?.destroy();
    }
    try {
      final response = await http
          .get(Uri.parse('http://$host:$_backendPort/docs'))
          .timeout(const Duration(milliseconds: 900));
      return response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }
}
