import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'file_saver_service.dart';

enum BgStage { downloading, saving, success, error, cancelled }

class BackgroundDownload {
  final String jobId;
  final String url;
  final String? folderPath;
  final bool audioOnly;
  final String audioFormat;
  final bool fromBrowser;

  String? title;
  BgStage stage;
  int downloadedBytes;
  int? totalBytes;
  double? speed;
  int? eta;
  double saveProgress;
  String? errorMessage;

  BackgroundDownload({
    required this.jobId,
    required this.url,
    required this.folderPath,
    required this.audioOnly,
    required this.audioFormat,
    this.fromBrowser = false,
    this.title,
    this.stage = BgStage.downloading,
    this.downloadedBytes = 0,
    this.totalBytes,
    this.speed,
    this.eta,
    this.saveProgress = 0,
    this.errorMessage,
  });

  double? get fraction {
    if (stage == BgStage.saving) {
      return saveProgress;
    }
    if (totalBytes != null && totalBytes! > 0) {
      return downloadedBytes / totalBytes!;
    }
    return null;
  }

  bool get isActive => stage == BgStage.downloading || stage == BgStage.saving;
}

/// Keeps downloads running (and their file-save step) independent of any
/// particular screen/dialog, so closing the progress popup ("Hide") doesn't
/// interrupt the download. Survives navigation; lives for the app's lifetime.
class BackgroundDownloadManager extends ChangeNotifier {
  BackgroundDownloadManager._();
  static final BackgroundDownloadManager instance =
      BackgroundDownloadManager._();

  final _api = ApiService();
  final _fileSaver = FileSaverService();
  final Map<String, BackgroundDownload> _downloads = {};
  final Map<String, StreamSubscription<Map<String, dynamic>>> _subs = {};

  List<BackgroundDownload> get all => _downloads.values.toList();
  List<BackgroundDownload> get active =>
      _downloads.values.where((d) => d.isActive).toList();
  int get activeCount => active.length;

  BackgroundDownload? get(String jobId) => _downloads[jobId];

  /// Starts tracking a job that has already been created via ApiService.startDownloadJob.
  void track({
    required String jobId,
    required String url,
    required String? folderPath,
    required bool audioOnly,
    required String audioFormat,
    bool fromBrowser = false,
  }) {
    final download = BackgroundDownload(
      jobId: jobId,
      url: url,
      folderPath: folderPath,
      audioOnly: audioOnly,
      audioFormat: audioFormat,
      fromBrowser: fromBrowser,
    );
    _downloads[jobId] = download;
    _subs[jobId] = _api
        .streamJobEvents(jobId)
        .listen(
          (event) => _onEvent(jobId, event),
          onError: (e) => _onError(jobId, e.toString()),
        );
    notifyListeners();
  }

  void _onEvent(String jobId, Map<String, dynamic> event) {
    final d = _downloads[jobId];
    if (d == null) return;
    switch (event['status'] as String?) {
      case 'downloading':
        d.downloadedBytes =
            (event['downloaded_bytes'] as num?)?.toInt() ?? d.downloadedBytes;
        d.totalBytes = (event['total_bytes'] as num?)?.toInt();
        d.speed = (event['speed'] as num?)?.toDouble();
        d.eta = (event['eta'] as num?)?.toInt();
        notifyListeners();
      case 'retrying':
      case 'merging':
        break;
      case 'cancelled':
        d.stage = BgStage.cancelled;
        notifyListeners();
      case 'finished':
        _onFinished(
          jobId,
          event['filename'] as String,
          event['title'] as String?,
        );
      case 'error':
        _onError(jobId, event['error'] as String? ?? 'Download failed');
    }
  }

  Future<void> _onFinished(String jobId, String filename, String? title) async {
    final d = _downloads[jobId];
    if (d == null) return;
    d.stage = BgStage.saving;
    d.title = title;
    d.saveProgress = 0;
    notifyListeners();
    try {
      final folderPath = d.folderPath;
      if (folderPath == null) throw Exception('No folder set');
      await _fileSaver.downloadToFolder(
        folderPath: folderPath,
        sourceUri: _api.fileUri(filename),
        filename: filename,
        onProgress: (p) {
          d.saveProgress = p;
          notifyListeners();
        },
      );
      d.stage = BgStage.success;
      notifyListeners();
      Timer(const Duration(seconds: 4), () {
        if (_downloads[jobId] == d) {
          dismiss(jobId);
        }
      });
    } catch (e) {
      _onError(jobId, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _onError(String jobId, String message) {
    final d = _downloads[jobId];
    if (d == null) return;
    d.stage = BgStage.error;
    d.errorMessage = message;
    notifyListeners();
    Timer(const Duration(seconds: 4), () {
      if (_downloads[jobId] == d) {
        dismiss(jobId);
      }
    });
  }

  void cancel(String jobId) {
    _subs[jobId]?.cancel();
    _subs.remove(jobId);
    _api.cancelJob(jobId).catchError((_) {});
    _downloads.remove(jobId);
    notifyListeners();
  }

  /// Removes a finished/error/cancelled entry from the History list (does not
  /// affect anything on the backend -- the file is already handled by then).
  void dismiss(String jobId) {
    _subs[jobId]?.cancel();
    _subs.remove(jobId);
    _downloads.remove(jobId);
    notifyListeners();
  }
}
