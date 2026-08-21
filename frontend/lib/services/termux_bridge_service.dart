import 'dart:io';

import 'package:flutter/services.dart';

/// Talks to Termux's RUN_COMMAND service through the same native channel
/// already used for the overlay bubble (see MainActivity.kt). Lets the app
/// start (and set up) the backend inside Termux with a couple of taps
/// instead of the person opening Termux and typing commands by hand.
class TermuxBridgeService {
  TermuxBridgeService._();
  static final TermuxBridgeService instance = TermuxBridgeService._();

  static const _channel = MethodChannel('all_in_1_downloader/overlay');

  static const String defaultCommand =
      'cd ~/all-in-1-downloader/backend && '
      'source .venv/bin/activate && '
      'uvicorn app.main:app --host 0.0.0.0 --port 8000';

  /// One-time command the person pastes inside Termux itself. This can
  /// never be sent programmatically -- it lives in Termux's own private
  /// settings file, which no other app is allowed to touch. That boundary
  /// is intentional (it's what stops any app from silently running shell
  /// commands on your phone without you ever opening Termux yourself).
  static const String allowExternalAppsCommand =
      'echo "allow-external-apps=true" >> ~/.termux/termux.properties '
      '&& termux-reload-settings';

  /// Full one-shot provisioning command: installs what's needed, clones the
  /// backend from [repoUrl], and sets up its Python environment. Does not
  /// start the server -- use [defaultCommand] for that afterwards.
  static String buildSetupCommand(String repoUrl) {
    return 'pkg update -y && pkg upgrade -y && '
        'pkg install -y python git ffmpeg && '
        'rm -rf ~/all-in-1-downloader && '
        'git clone $repoUrl ~/all-in-1-downloader && '
        'cd ~/all-in-1-downloader/backend && '
        'python -m venv .venv && '
        'source .venv/bin/activate && '
        'pip install -r requirements.txt';
  }

  Future<bool> isTermuxInstalled() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isTermuxInstalled') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Launches Termux directly so the person can paste a copied command.
  Future<bool> openTermux() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('openTermux') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasRunCommandPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('hasRunCommandPermission') ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Shows Android's real permission dialog for com.termux.permission.RUN_COMMAND.
  /// Only works once Termux is installed (the permission doesn't exist on
  /// the device until Termux registers it).
  Future<bool> requestRunCommandPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('requestRunCommandPermission') ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Sends [command] to Termux to run in the background. Returns true if
  /// the request was successfully dispatched -- this does NOT confirm the
  /// backend actually started (e.g. Termux silently refuses if the person
  /// hasn't enabled "allow-external-apps" yet), only that the intent was
  /// sent without error.
  Future<bool> runCommand(String command) async {
    if (!Platform.isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('runTermuxCommand', {
        'command': command,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}
