import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

enum _Busy { none, permission, setup, start }

class _TermuxSetupScreenState extends State<TermuxSetupScreen>
    with WidgetsBindingObserver {
  final _bridge = TermuxBridgeService.instance;
  late final TextEditingController _repoController;

  bool _termuxInstalled = false;
  bool _hasPermission = false;
  _Busy _busy = _Busy.none;
  String? _setupStatus;
  String? _startStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repoController = TextEditingController(
      text: BackendConfigService.instance.termuxRepoUrl,
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
    setState(() => _busy = _Busy.permission);
    final granted = await _bridge.requestRunCommandPermission();
    if (!mounted) return;
    setState(() {
      _hasPermission = granted;
      _busy = _Busy.none;
    });
  }

  Future<void> _copyAndOpenTermux() async {
    await Clipboard.setData(
      const ClipboardData(text: TermuxBridgeService.allowExternalAppsCommand),
    );
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => _OpenTermuxDialog(
        onOpen: () {
          Navigator.of(context).pop();
          _bridge.openTermux();
        },
      ),
    );
  }

  Future<void> _runSetup() async {
    final repo = _repoController.text.trim();
    if (repo.isEmpty) {
      setState(() => _setupStatus = 'Paste your GitHub repo link first.');
      return;
    }
    await BackendConfigService.instance.setTermuxRepoUrl(repo);
    setState(() {
      _busy = _Busy.setup;
      _setupStatus = null;
    });
    final installed = await _bridge.isTermuxInstalled();
    if (!installed) {
      if (!mounted) return;
      setState(() {
        _busy = _Busy.none;
        _setupStatus = 'Termux isn\'t installed yet -- see step 1 above.';
      });
      return;
    }
    final sent = await _bridge.runCommand(
      TermuxBridgeService.buildSetupCommand(repo),
    );
    if (!mounted) return;
    setState(() {
      _busy = _Busy.none;
      _setupStatus = sent
          ? 'Sent to Termux. First run installs Python/ffmpeg and clones '
                'the repo -- this can take several minutes. Open Termux to '
                'watch progress.'
          : 'Could not reach Termux. Make sure step 2 (the one-time paste) '
                'is done.';
    });
  }

  Future<void> _startBackend() async {
    setState(() {
      _busy = _Busy.start;
      _startStatus = null;
    });
    final installed = await _bridge.isTermuxInstalled();
    if (!installed) {
      if (!mounted) return;
      setState(() {
        _busy = _Busy.none;
        _startStatus = 'Termux isn\'t installed yet -- see step 1 above.';
      });
      return;
    }
    final sent = await _bridge.runCommand(
      BackendConfigService.instance.termuxCommand,
    );
    if (!mounted) return;
    setState(() {
      _busy = _Busy.none;
      _startStatus = sent
          ? 'Sent to Termux. Give it a few seconds, then go to Settings and '
                'use Auto-detect to confirm it\'s reachable.'
          : 'Could not reach Termux. Make sure step 2 (the one-time paste) '
                'is done.';
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
                                busy: _busy == _Busy.permission,
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
                              'for you. Tap below to copy it, then paste '
                              '(long-press → Paste) and press Enter in '
                              'Termux, then close and reopen Termux once.',
                              style: TextStyle(
                                color: colors.textFaint,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SelectableText(
                              TermuxBridgeService.allowExternalAppsCommand,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 10),
                            _WizardButton(
                              label: 'Copy command',
                              icon: Icons.copy_rounded,
                              onTap: _copyAndOpenTermux,
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
                              'Paste your GitHub repo link:',
                              style: TextStyle(
                                color: colors.textFaint,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            NeomorphicContainer(
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
                                  fontSize: 13,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  hintText:
                                      'https://github.com/you/all-in-1-downloader.git',
                                  hintStyle: TextStyle(
                                    color: colors.textFaint,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _WizardButton(
                              label: 'Download & Setup Backend',
                              icon: Icons.cloud_download_rounded,
                              busy: _busy == _Busy.setup,
                              onTap: _runSetup,
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
                        done: false,
                        colors: colors,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _WizardButton(
                              label: 'Start Backend via Termux',
                              icon: Icons.terminal_rounded,
                              busy: _busy == _Busy.start,
                              onTap: _startBackend,
                              colors: colors,
                            ),
                            if (_startStatus != null) ...[
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

class _WizardButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool busy;
  final colors;

  const _WizardButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.colors,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: busy ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.accent, width: 1.3),
        ),
        child: busy
            ? SizedBox(width: 16, height: 16, child: OrbitLoader(size: 16))
            : Row(
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
  final VoidCallback onOpen;

  const _OpenTermuxDialog({required this.onOpen});

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
        'Now open Termux, paste it (long-press → Paste), and press Enter. '
        'Then close and reopen Termux once.',
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
