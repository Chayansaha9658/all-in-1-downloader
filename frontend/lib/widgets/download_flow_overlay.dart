import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/video_info.dart';
import '../services/api_service.dart';
import '../services/background_download_manager.dart';
import '../services/file_saver_service.dart';
import '../services/folder_service.dart';
import '../services/theme_controller.dart';
import 'neomorphic_container.dart';
import 'orbit_loader.dart';
import 'progress_ring.dart';
import 'tap_scale.dart';

enum _FlowStage { downloading, saving, success, error }

Future<bool?> showDownloadFlowOverlay(
  BuildContext context, {
  required String url,
  String? formatId,
  bool audioOnly = false,
  String audioFormat = 'mp3',
  String? title,
}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, _, _) => DownloadFlowOverlay(
      url: url,
      formatId: formatId,
      audioOnly: audioOnly,
      audioFormat: audioFormat,
      knownTitle: title,
    ),
    transitionBuilder: (context, animation, _, child) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.92, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      );
    },
  );
}

class DownloadFlowOverlay extends StatefulWidget {
  final String url;
  final String? formatId;
  final bool audioOnly;
  final String audioFormat;
  final String? knownTitle;

  const DownloadFlowOverlay({
    super.key,
    required this.url,
    this.formatId,
    this.audioOnly = false,
    this.audioFormat = 'mp3',
    this.knownTitle,
  });

  @override
  State<DownloadFlowOverlay> createState() => _DownloadFlowOverlayState();
}

class _DownloadFlowOverlayState extends State<DownloadFlowOverlay>
    with TickerProviderStateMixin {
  final _api = ApiService();
  final _folderService = FolderService();
  final _fileSaver = FileSaverService();

  late final AnimationController _waveController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  _FlowStage _stage = _FlowStage.downloading;
  String? _folderPath;
  String? _jobId;
  int _downloadedBytes = 0;
  int? _totalBytes;
  double? _speed;
  int? _eta;
  double _saveProgress = 0;
  String? _errorMessage;
  String? _resultTitle;
  StreamSubscription<Map<String, dynamic>>? _sub;
  Timer? _autoCloseTimer;
  bool _handedOff = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final folder = await _folderService.getSavedFolder();
    if (!mounted) return;
    _folderPath = folder;
    _beginDownload();
  }

  Future<void> _beginDownload() async {
    setState(() {
      _errorMessage = null;
    });
    try {
      final jobId = await _api.startDownloadJob(
        url: widget.url,
        formatId: widget.formatId,
        audioOnly: widget.audioOnly,
        audioFormat: widget.audioFormat,
        title: widget.knownTitle,
      );
      if (!mounted) return;
      _jobId = jobId;
      _sub = _api
          .streamJobEvents(jobId)
          .listen(_onEvent, onError: _onStreamError);
    } catch (e) {
      _onError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _onEvent(Map<String, dynamic> event) {
    if (!mounted) return;
    switch (event['status'] as String?) {
      case 'downloading':
        setState(() {
          _downloadedBytes =
              (event['downloaded_bytes'] as num?)?.toInt() ?? _downloadedBytes;
          _totalBytes = (event['total_bytes'] as num?)?.toInt();
          _speed = (event['speed'] as num?)?.toDouble();
          _eta = (event['eta'] as num?)?.toInt();
        });
      case 'retrying':
      case 'merging':
        break;
      case 'cancelled':
        break;
      case 'finished':
        _onFinished(event['filename'] as String, event['title'] as String?);
      case 'error':
        _onError(event['error'] as String? ?? 'Download failed');
    }
  }

  void _onStreamError(Object e) => _onError(e.toString());

  Future<void> _onFinished(String filename, String? title) async {
    setState(() {
      _stage = _FlowStage.saving;
      _resultTitle = title;
      _saveProgress = 0;
    });
    try {
      await _fileSaver.downloadToFolder(
        folderPath: _folderPath!,
        sourceUri: _api.fileUri(filename),
        filename: filename,
        onProgress: (p) {
          if (mounted) setState(() => _saveProgress = p);
        },
      );
      if (!mounted) return;
      setState(() => _stage = _FlowStage.success);
      _autoCloseTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) Navigator.of(context).pop(true);
      });
    } catch (e) {
      _onError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _onError(String message) {
    if (!mounted) return;
    setState(() {
      _stage = _FlowStage.error;
      _errorMessage = message;
    });
  }

  void _dismissSuccess() {
    _autoCloseTimer?.cancel();
    if (mounted) Navigator.of(context).pop(true);
  }

  void _openFolderAndDismiss() {
    if (_folderPath != null) {
      Process.run('open', [_folderPath!]);
    }
    _dismissSuccess();
  }

  void _cancelDownload() {
    _sub?.cancel();
    final jobId = _jobId;
    if (jobId != null) {
      _api.cancelJob(jobId).catchError((_) {});
    }
    if (mounted) Navigator.of(context).pop(false);
  }

  void _hideAndBackground() {
    final jobId = _jobId;
    if (jobId == null) {
      Navigator.of(context).pop(false);
      return;
    }
    _sub?.cancel();
    _handedOff = true;
    BackgroundDownloadManager.instance.track(
      jobId: jobId,
      url: widget.url,
      folderPath: _folderPath,
      audioOnly: widget.audioOnly,
      audioFormat: widget.audioFormat,
    );
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    if (!_handedOff) {
      _sub?.cancel();
    }
    _autoCloseTimer?.cancel();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _waveController,
        builder: (context, child) {
          final t = _waveController.value * 2 * pi;
          return Transform.translate(
            offset: Offset(0, sin(t) * 5),
            child: Transform.scale(scale: 1.0 + sin(t) * 0.012, child: child),
          );
        },
        child: _buildCard(),
      ),
    );
  }

  Widget _buildCard() {
    final showHide =
        _stage == _FlowStage.downloading || _stage == _FlowStage.saving;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: NeomorphicContainer(
        borderRadius: BorderRadius.circular(28),
        padding: const EdgeInsets.all(24),
        intensity: 8,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _buildContent(),
            if (_stage == _FlowStage.success)
              Positioned(
                top: -8,
                right: -8,
                child: _CloseButton(onTap: _dismissSuccess),
              ),
            if (showHide)
              Positioned(
                top: -8,
                right: -8,
                child: _HideButton(onTap: _hideAndBackground),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_stage) {
      case _FlowStage.downloading:
        return _ProgressView(
          title: 'Downloading',
          downloadedBytes: _downloadedBytes,
          totalBytes: _totalBytes,
          speed: _speed,
          eta: _eta,
          onCancel: _cancelDownload,
        );
      case _FlowStage.saving:
        return _ProgressView(
          title: 'Saving to folder',
          downloadedBytes: (_saveProgress * (_totalBytes ?? 0)).round(),
          totalBytes: _totalBytes,
          speed: null,
          eta: null,
          fractionOverride: _saveProgress,
          onCancel: _cancelDownload,
        );
      case _FlowStage.success:
        return _SuccessView(
          title: _resultTitle,
          folderName: FolderService.folderName,
          onView: _openFolderAndDismiss,
        );
      case _FlowStage.error:
        return _ErrorView(
          message: _errorMessage ?? 'Something went wrong',
          onClose: () => Navigator.of(context).pop(false),
        );
    }
  }
}

class _ProgressView extends StatelessWidget {
  final String title;
  final int downloadedBytes;
  final int? totalBytes;
  final double? speed;
  final int? eta;
  final double? fractionOverride;
  final VoidCallback onCancel;

  const _ProgressView({
    required this.title,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.speed,
    required this.eta,
    required this.onCancel,
    this.fractionOverride,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ThemeController.instance.colors;
    final fraction =
        fractionOverride ??
        ((totalBytes != null && totalBytes! > 0)
            ? downloadedBytes / totalBytes!
            : null);
    final isPreparing = fraction == null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isPreparing)
          const SizedBox(
            width: 110,
            height: 110,
            child: Center(child: OrbitLoader(size: 56)),
          )
        else
          ProgressRing(progress: fraction),
        const SizedBox(height: 16),
        Text(
          isPreparing ? 'Preparing...' : title,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        if (!isPreparing)
          Text(
            '${formatBytes(downloadedBytes)} / ${totalBytes != null ? formatBytes(totalBytes) : '--'}',
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
        if (speed != null || eta != null) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (speed != null)
                Text(
                  '${formatBytes(speed!.round())}/s',
                  style: TextStyle(color: colors.textFaint, fontSize: 12),
                ),
              if (speed != null && eta != null)
                Text(
                  '   •   ',
                  style: TextStyle(color: colors.textFaint, fontSize: 12),
                ),
              if (eta != null)
                Text(
                  '${eta}s left',
                  style: TextStyle(color: colors.textFaint, fontSize: 12),
                ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        TapScale(
          onTap: onCancel,
          child: Container(
            width: double.infinity,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: colors.background,
              boxShadow: [
                BoxShadow(
                  color: colors.shadowDark,
                  offset: const Offset(3, 3),
                  blurRadius: 6,
                ),
                BoxShadow(
                  color: colors.shadowLight,
                  offset: const Offset(-3, -3),
                  blurRadius: 6,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              'Cancel',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SuccessView extends StatelessWidget {
  final String? title;
  final String folderName;
  final VoidCallback onView;

  const _SuccessView({
    required this.title,
    required this.folderName,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ThemeController.instance.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [colors.audioStart, colors.audioEnd],
            ),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 16),
        Text(
          'Saved!',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Saved to "$folderName"',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),
        TapScale(
          onTap: onView,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: colors.background,
              boxShadow: [
                BoxShadow(
                  color: colors.shadowDark,
                  offset: const Offset(3, 3),
                  blurRadius: 6,
                ),
                BoxShadow(
                  color: colors.shadowLight,
                  offset: const Offset(-3, -3),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.folder_open_rounded,
                  color: colors.textPrimary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'View',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = ThemeController.instance.colors;
    return TapScale(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.background,
          boxShadow: [
            BoxShadow(
              color: colors.shadowDark,
              offset: const Offset(2, 2),
              blurRadius: 5,
            ),
            BoxShadow(
              color: colors.shadowLight,
              offset: const Offset(-2, -2),
              blurRadius: 5,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(Icons.close_rounded, color: colors.textPrimary, size: 16),
      ),
    );
  }
}

class _HideButton extends StatelessWidget {
  final VoidCallback onTap;

  const _HideButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = ThemeController.instance.colors;
    return TapScale(
      onTap: onTap,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: colors.background,
          boxShadow: [
            BoxShadow(
              color: colors.shadowDark,
              offset: const Offset(2, 2),
              blurRadius: 5,
            ),
            BoxShadow(
              color: colors.shadowLight,
              offset: const Offset(-2, -2),
              blurRadius: 5,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.remove_red_eye_outlined,
              color: colors.textPrimary,
              size: 13,
            ),
            const SizedBox(width: 4),
            Text(
              'Hide',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onClose;

  const _ErrorView({required this.message, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final colors = ThemeController.instance.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.withValues(alpha: 0.18),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFE85D75),
            size: 30,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Download failed',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 18),
        TapScale(
          onTap: onClose,
          child: Container(
            width: double.infinity,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: colors.background,
              boxShadow: [
                BoxShadow(
                  color: colors.shadowDark,
                  offset: const Offset(3, 3),
                  blurRadius: 6,
                ),
                BoxShadow(
                  color: colors.shadowLight,
                  offset: const Offset(-3, -3),
                  blurRadius: 6,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              'Close',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
