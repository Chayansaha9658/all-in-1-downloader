import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../services/backend_config_service.dart';
import '../services/browser_session_manager.dart';
import '../services/termux_bridge_service.dart';
import '../services/theme_controller.dart';
import '../tools/browser_screen.dart';
import '../widgets/neomorphic_container.dart';
import '../widgets/orbit_loader.dart';
import '../widgets/tap_scale.dart';

class TermuxSetupScreen extends StatefulWidget {
  const TermuxSetupScreen({super.key});

  @override
  State<TermuxSetupScreen> createState() => _TermuxSetupScreenState();
}

class _TermuxSetupScreenState extends State<TermuxSetupScreen>
    with WidgetsBindingObserver {
  final _bridge = TermuxBridgeService.instance;
  late final TextEditingController _repoController;

  bool _termuxInstalled = false;
  bool _hasPermission = false;
  bool _verifyingBackend = false;
  bool _backendVerified = false;
  String? _setupStatus;
  String? _startStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final savedRepo = BackendConfigService.instance.termuxRepoUrl;
    _repoController = TextEditingController(
      text: savedRepo.isNotEmpty
          ? savedRepo
          : TermuxBridgeService.defaultRepoUrl,
    );
    _refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _repoController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check after the person comes back from Termux/F-Droid/Settings.
    if (state == AppLifecycleState.resumed) _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final installed = await _bridge.isTermuxInstalled();
    final permission = await _bridge.hasRunCommandPermission();
    if (!mounted) return;
    setState(() {
      _termuxInstalled = installed;
      _hasPermission = permission;
    });
  }

  void _openF_droidTermux() {
    BrowserSessionManager.instance.addTab(
      url: 'https://f-droid.org/packages/com.termux/',
    );
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const BrowserScreen()));
  }

  Future<void> _grantPermission() async {
    setState(() => _hasPermission = false);
    final granted = await _bridge.requestRunCommandPermission();
    if (!mounted) return;
    setState(() => _hasPermission = granted);
  }

  Future<void> _copyOpenPaste({
    required String command,
    required String message,
    VoidCallback? onOpened,
  }) async {
    await Clipboard.setData(ClipboardData(text: command));
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => _OpenTermuxDialog(
        message: message,
        onOpen: () {
          Navigator.of(context).pop();
          _bridge.openTermux();
          onOpened?.call();
        },
      ),
    );
  }

  Future<void> _copyAllowExternalApps() {
    return _copyOpenPaste(
      command: TermuxBridgeService.allowExternalAppsCommand,
      message:
          'Now open Termux, paste it (long-press → Paste), and press '
          'Enter. Then close and reopen Termux once.',
    );
  }

  Future<void> _copySetupCommand() async {
    final repo = _repoController.text.trim();
    if (repo.isEmpty) {
      setState(() => _setupStatus = 'Paste your GitHub repo link first.');
      return;
    }
    await BackendConfigService.instance.setTermuxRepoUrl(repo);
    setState(() => _setupStatus = null);
    await _copyOpenPaste(
      command: TermuxBridgeService.buildSetupCommand(repo),
      message:
          'Now open Termux, paste it (long-press → Paste), and press '
          'Enter. First run installs Python/ffmpeg and clones the repo -- '
          'this can take several minutes. Come back here when it finishes.',
    );
  }

  Future<void> _copyStartCommand() async {
    // The backend runs on this same phone, so point the app at localhost
    // right away instead of making the person type/scan for it.
    await BackendConfigService.instance.setBaseUrl('127.0.0.1:8000');
    setState(() {
      _startStatus = null;
      _backendVerified = false;
    });
    await _copyOpenPaste(
      command: BackendConfigService.instance.termuxCommand,
      message:
          'Now open Termux, paste it (long-press → Paste), and press '
          'Enter to start the server.',
      onOpened: _verifyBackend,
    );
  }

  Future<void> _verifyBackend() async {
    setState(() => _verifyingBackend = true);
    for (var i = 0; i < 15; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      try {
        final response = await http
            .get(Uri.parse('http://127.0.0.1:8000/docs'))
            .timeout(const Duration(seconds: 2));
        if (response.statusCode < 500) {
          setState(() {
            _verifyingBackend = false;
            _backendVerified = true;
            _startStatus = 'Backend is running.';
          });
          return;
        }
      } catch (_) {
        // Not up yet -- keep polling.
      }
    }
    if (!mounted) return;
    setState(() {
      _verifyingBackend = false;
      _startStatus =
          'Still not reachable. Open Termux and check for errors -- if '
          'step 4 is still installing, wait for it to finish and try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final colors = ThemeController.instance.colors;
        return Scaffold(
          backgroundColor: colors.background,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 20, 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        'Termux Setup',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                    children: [
                      _StepCard(
                        number: 1,
                        title: 'Install Termux',
                        done: _termuxInstalled,
                        colors: colors,
                        child: _termuxInstalled
                            ? Text(
                                'Termux is installed.',
                                style: TextStyle(
                                  color: colors.textFaint,
                                  fontSize: 12.5,
                                ),
                              )
                            : _WizardButton(
                                label: 'Get Termux (F-Droid)',
                                icon: Icons.open_in_new_rounded,
                                onTap: _openF_droidTermux,
                                colors: colors,
                              ),
                      ),
                      const SizedBox(height: 14),
                      _StepCard(
                        number: 2,
                        title: 'Grant command permission',
                        done: _hasPermission,
                        colors: colors,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lets this app ask Termux to run things -- a '
                              'normal Android permission popup.',
                              style: TextStyle(
                                color: colors.textFaint,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (!_hasPermission)
                              _WizardButton(
                                label: 'Grant permission',
                                icon: Icons.verified_user_rounded,
                                onTap: _grantPermission,
                                colors: colors,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _StepCard(
                        number: 3,
                        title: 'One-time: allow external commands',
                        done: false,
                        colors: colors,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'This one line lives inside Termux\'s own '
                              'private settings, so only you (inside '
                              'Termux) can set it -- no app can do this '
                              'for you.',
                              style: TextStyle(
                                color: colors.textFaint,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _CopyableCommand(
                              command:
                                  TermuxBridgeService.allowExternalAppsCommand,
                              colors: colors,
                            ),
                            const SizedBox(height: 10),
                            _WizardButton(
                              label: 'Copy & Open Termux',
                              icon: Icons.copy_rounded,
                              onTap: _copyAllowExternalApps,
                              colors: colors,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _StepCard(
                        number: 4,
                        title: 'Download & set up backend',
                        done: false,
                        colors: colors,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your backend\'s GitHub link (already filled '
                              'in -- edit only if it changes):',
                              style: TextStyle(
                                color: colors.textFaint,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: NeomorphicContainer(
                                    style: NeoStyle.pressed,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 4,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    child: TextField(
                                      controller: _repoController,
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 12.5,
                                      ),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        border: InputBorder.none,
                                        hintText:
                                            'https://github.com/you/repo.git',
                                        hintStyle: TextStyle(
                                          color: colors.textFaint,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _CopyIconButton(
                                  getText: () => _repoController.text.trim(),
                                  colors: colors,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _WizardButton(
                              label: 'Copy & Open Termux',
                              icon: Icons.cloud_download_rounded,
                              onTap: _copySetupCommand,
                              colors: colors,
                            ),
                            if (_setupStatus != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _setupStatus!,
                                style: TextStyle(
                                  color: colors.textFaint,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _StepCard(
                        number: 5,
                        title: 'Start the backend',
                        done: _backendVerified,
                        colors: colors,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _CopyableCommand(
                              command:
                                  BackendConfigService.instance.termuxCommand,
                              colors: colors,
                            ),
                            const SizedBox(height: 10),
                            _WizardButton(
                              label: 'Copy & Open Termux',
                              icon: Icons.terminal_rounded,
                              onTap: _copyStartCommand,
                              colors: colors,
                            ),
                            if (_verifyingBackend) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: OrbitLoader(size: 14),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Checking if it\'s reachable...',
                                    style: TextStyle(
                                      color: colors.textFaint,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (_backendVerified) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF4ADE80),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Backend is running!',
                                    style: TextStyle(
                                      color: const Color(0xFF4ADE80),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (_startStatus != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _startStatus!,
                                style: TextStyle(
                                  color: colors.textFaint,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StepCard extends StatelessWidget {
  final int number;
  final String title;
  final bool done;
  final Widget child;
  final colors;

  const _StepCard({
    required this.number,
    required this.title,
    required this.done,
    required this.child,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return NeomorphicContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? const Color(0xFF4ADE80)
                      : colors.shadowDark.withValues(alpha: 0.4),
                ),
                child: done
                    ? const Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: Colors.white,
                      )
                    : Text(
                        '$number',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _CopyableCommand extends StatelessWidget {
  final String command;
  final colors;

  const _CopyableCommand({required this.command, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SelectableText(
            command,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(width: 6),
        _CopyIconButton(getText: () => command, colors: colors),
      ],
    );
  }
}

class _CopyIconButton extends StatelessWidget {
  final String Function() getText;
  final colors;

  const _CopyIconButton({required this.getText, required this.colors});

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: () => Clipboard.setData(ClipboardData(text: getText())),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colors.shadowDark),
        ),
        child: Icon(Icons.copy_rounded, size: 15, color: colors.textFaint),
      ),
    );
  }
}

class _WizardButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final colors;

  const _WizardButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.accent, width: 1.3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: colors.accent, size: 17),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: colors.accent,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenTermuxDialog extends StatelessWidget {
  final String message;
  final VoidCallback onOpen;

  const _OpenTermuxDialog({required this.message, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final colors = ThemeController.instance.colors;
    return AlertDialog(
      backgroundColor: colors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Command copied',
        style: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Text(
        message,
        style: TextStyle(color: colors.textFaint, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Later', style: TextStyle(color: colors.textFaint)),
        ),
        TextButton(
          onPressed: onOpen,
          child: Text(
            'Open Termux',
            style: TextStyle(color: colors.accent, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
