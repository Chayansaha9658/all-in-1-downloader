import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/backend_config_service.dart';
import '../services/termux_bridge_service.dart';
import '../services/theme_controller.dart';
import '../screens/termux_setup_screen.dart';
import '../widgets/neomorphic_container.dart';
import '../widgets/orbit_loader.dart';
import '../widgets/tap_scale.dart';

Future<void> showBackendSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const _BackendSettingsSheet(),
  );
}

enum _TestState { idle, checking, success, failure }

enum _ScanState { idle, scanning, notFound }

enum _TermuxState { idle, sending, sent, notInstalled, error }

class _BackendSettingsSheet extends StatefulWidget {
  const _BackendSettingsSheet();

  @override
  State<_BackendSettingsSheet> createState() => _BackendSettingsSheetState();
}

class _BackendSettingsSheetState extends State<_BackendSettingsSheet> {
  late final TextEditingController _controller;
  late final TextEditingController _termuxController;
  _TestState _state = _TestState.idle;
  _ScanState _scanState = _ScanState.idle;
  _TermuxState _termuxState = _TermuxState.idle;
  int _scanChecked = 0;
  int _scanTotal = 0;

  bool get _busy =>
      _state == _TestState.checking || _scanState == _ScanState.scanning;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: BackendConfigService.instance.baseUrl,
    );
    _termuxController = TextEditingController(
      text: BackendConfigService.instance.termuxCommand,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _termuxController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _state = _TestState.checking);
    await BackendConfigService.instance.setBaseUrl(_controller.text);
    _controller.text = BackendConfigService.instance.baseUrl;
    await _test();
  }

  Future<void> _test() async {
    setState(() => _state = _TestState.checking);
    try {
      final base = BackendConfigService.instance.baseUrl;
      final response = await http
          .get(Uri.parse('$base/docs'))
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;
      setState(() {
        _state = response.statusCode < 500
            ? _TestState.success
            : _TestState.failure;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _state = _TestState.failure);
    }
  }

  Future<void> _reset() async {
    await BackendConfigService.instance.resetToDefault();
    setState(() {
      _controller.text = BackendConfigService.instance.baseUrl;
      _state = _TestState.idle;
      _scanState = _ScanState.idle;
    });
  }

  Future<void> _autoDetect() async {
    setState(() {
      _scanState = _ScanState.scanning;
      _state = _TestState.idle;
      _scanChecked = 0;
      _scanTotal = 0;
    });
    final found = await BackendConfigService.instance.autoDetect(
      onProgress: (checked, total) {
        if (!mounted) return;
        setState(() {
          _scanChecked = checked;
          _scanTotal = total;
        });
      },
    );
    if (!mounted) return;
    if (found == null) {
      setState(() => _scanState = _ScanState.notFound);
      return;
    }
    setState(() => _scanState = _ScanState.idle);
    _controller.text = found;
    await BackendConfigService.instance.setBaseUrl(found);
    await _test();
  }

  Future<void> _runViaTermux() async {
    setState(() => _termuxState = _TermuxState.sending);
    final installed = await TermuxBridgeService.instance.isTermuxInstalled();
    if (!installed) {
      if (!mounted) return;
      setState(() => _termuxState = _TermuxState.notInstalled);
      return;
    }
    final command = _termuxController.text.trim();
    await BackendConfigService.instance.setTermuxCommand(command);
    final sent = await TermuxBridgeService.instance.runCommand(command);
    if (!mounted) return;
    setState(() {
      _termuxState = sent ? _TermuxState.sent : _TermuxState.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = ThemeController.instance.colors;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 20),
        child: NeomorphicContainer(
          borderRadius: BorderRadius.circular(28),
          intensity: 8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colors.shadowDark,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Text(
                'Backend server',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Don\'t know the IP? Tap Auto-detect below -- it scans your '
                'WiFi network and fills it in for you.',
                style: TextStyle(color: colors.textFaint, fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              TapScale(
                onTap: _busy ? null : _autoDetect,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.accent, width: 1.4),
                  ),
                  child: _scanState == _ScanState.scanning
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: OrbitLoader(size: 16),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _scanTotal > 0
                                  ? 'Scanning network... $_scanChecked/$_scanTotal'
                                  : 'Scanning network...',
                              style: TextStyle(
                                color: colors.accent,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.wifi_find_rounded,
                              color: colors.accent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Auto-detect',
                              style: TextStyle(
                                color: colors.accent,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              if (_scanState == _ScanState.notFound) ...[
                const SizedBox(height: 8),
                Text(
                  'No backend found on this WiFi network. Make sure it\'s '
                  'running and your phone is on the same network, then try '
                  'again -- or enter the IP manually below.',
                  style: TextStyle(
                    color: const Color(0xFFE85D75),
                    fontSize: 11.5,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      color: colors.shadowDark.withValues(alpha: 0.3),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'or enter manually',
                      style: TextStyle(color: colors.textFaint, fontSize: 11),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: colors.shadowDark.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              NeomorphicContainer(
                style: NeoStyle.pressed,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                borderRadius: BorderRadius.circular(14),
                child: TextField(
                  controller: _controller,
                  style: TextStyle(color: colors.textPrimary, fontSize: 14),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: '192.168.0.42:8000',
                    hintStyle: TextStyle(color: colors.textFaint, fontSize: 13),
                  ),
                  onSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(height: 10),
              _StatusLine(state: _state, colors: colors),
              if (Platform.isAndroid) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        color: colors.shadowDark.withValues(alpha: 0.3),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'run backend on this phone',
                        style: TextStyle(color: colors.textFaint, fontSize: 11),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: colors.shadowDark.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TapScale(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TermuxSetupScreen(),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        colors: [colors.videoStart, colors.videoEnd],
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 17,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'New here? Open guided Setup Wizard',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'One-time setup in Termux: install it from F-Droid, then '
                  'run this once inside Termux:',
                  style: TextStyle(color: colors.textFaint, fontSize: 11.5),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  'echo "allow-external-apps=true" >> ~/.termux/termux.properties '
                  '&& termux-reload-settings',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 12),
                NeomorphicContainer(
                  style: NeoStyle.pressed,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  child: TextField(
                    controller: _termuxController,
                    style: TextStyle(color: colors.textPrimary, fontSize: 12.5),
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Command Termux should run',
                      hintStyle: TextStyle(
                        color: colors.textFaint,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TapScale(
                  onTap: _termuxState == _TermuxState.sending
                      ? null
                      : _runViaTermux,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.accent, width: 1.4),
                    ),
                    child: _termuxState == _TermuxState.sending
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: OrbitLoader(size: 16),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Starting...',
                                style: TextStyle(
                                  color: colors.accent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.terminal_rounded,
                                color: colors.accent,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Start Backend via Termux',
                                style: TextStyle(
                                  color: colors.accent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                if (_termuxState == _TermuxState.sent) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF4ADE80),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Sent to Termux. Give it a few seconds, then use '
                          'Auto-detect or Save & Test above to confirm.',
                          style: TextStyle(
                            color: const Color(0xFF4ADE80),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (_termuxState == _TermuxState.notInstalled) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Termux isn\'t installed on this phone. Install it from '
                    'F-Droid first.',
                    style: TextStyle(
                      color: const Color(0xFFE85D75),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (_termuxState == _TermuxState.error) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Could not reach Termux. Make sure "allow-external-apps" '
                    'is enabled (see command above).',
                    style: TextStyle(
                      color: const Color(0xFFE85D75),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TapScale(
                      onTap: _busy ? null : _reset,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.shadowDark),
                        ),
                        child: Text(
                          'Reset',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TapScale(
                      onTap: _busy ? null : _save,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [colors.videoStart, colors.videoEnd],
                          ),
                        ),
                        child: _state == _TestState.checking
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: OrbitLoader(size: 18),
                              )
                            : const Text(
                                'Save & Test',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  final _TestState state;
  final colors;

  const _StatusLine({required this.state, required this.colors});

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _TestState.idle:
        return const SizedBox.shrink();
      case _TestState.checking:
        return Text(
          'Checking connection...',
          style: TextStyle(color: colors.textFaint, fontSize: 12.5),
        );
      case _TestState.success:
        return Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF4ADE80),
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              'Connected',
              style: TextStyle(
                color: const Color(0xFF4ADE80),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      case _TestState.failure:
        return Row(
          children: [
            const Icon(Icons.error_rounded, color: Color(0xFFE85D75), size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Could not reach this address. Check the backend is '
                'running and the IP is correct.',
                style: TextStyle(
                  color: const Color(0xFFE85D75),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
    }
  }
}
