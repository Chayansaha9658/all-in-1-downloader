import 'dart:io';

import 'package:flutter/material.dart';

import '../models/video_info.dart';
import '../services/background_download_manager.dart';
import '../services/theme_controller.dart';
import '../widgets/neomorphic_container.dart';
import '../widgets/orbit_loader.dart';
import '../widgets/tap_scale.dart';

Future<void> showHistorySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const _HistorySheet(),
  );
}

class _HistorySheet extends StatelessWidget {
  const _HistorySheet();

  @override
  Widget build(BuildContext context) {
    final colors = ThemeController.instance.colors;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
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
                'Downloads',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Running in the background',
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListenableBuilder(
                  listenable: BackgroundDownloadManager.instance,
                  builder: (context, _) {
                    final items = BackgroundDownloadManager.instance.all;
                    if (items.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            'No background downloads',
                            style: TextStyle(
                              color: colors.textFaint,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _HistoryRow(item: items[i]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final BackgroundDownload item;

  const _HistoryRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = ThemeController.instance.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(18),
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
        children: [
          _leading(colors),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title ?? item.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                _subtitle(colors),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _trailing(context, colors),
        ],
      ),
    );
  }

  Widget _leading(colors) {
    switch (item.stage) {
      case BgStage.downloading:
      case BgStage.saving:
        return SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            value: item.fraction,
            strokeWidth: 3,
            backgroundColor: colors.shadowDark.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation(colors.accent),
          ),
        );
      case BgStage.success:
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [colors.audioStart, colors.audioEnd],
            ),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
        );
      case BgStage.error:
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.withValues(alpha: 0.18),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFE85D75),
            size: 18,
          ),
        );
      case BgStage.cancelled:
        return const SizedBox(
          width: 32,
          height: 32,
          child: OrbitLoader(size: 20),
        );
    }
  }

  Widget _subtitle(colors) {
    switch (item.stage) {
      case BgStage.downloading:
        final parts = <String>[
          '${formatBytes(item.downloadedBytes)} / ${item.totalBytes != null ? formatBytes(item.totalBytes) : '--'}',
        ];
        if (item.speed != null)
          parts.add('${formatBytes(item.speed!.round())}/s');
        if (item.eta != null) parts.add('${item.eta}s left');
        return Text(
          parts.join('  •  '),
          style: TextStyle(color: colors.textFaint, fontSize: 11.5),
        );
      case BgStage.saving:
        return Text(
          'Saving to folder...',
          style: TextStyle(color: colors.textFaint, fontSize: 11.5),
        );
      case BgStage.success:
        return Text(
          'Completed',
          style: TextStyle(color: colors.textFaint, fontSize: 11.5),
        );
      case BgStage.error:
        return Text(
          item.errorMessage ?? 'Failed',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFFE85D75), fontSize: 11.5),
        );
      case BgStage.cancelled:
        return Text(
          'Cancelled',
          style: TextStyle(color: colors.textFaint, fontSize: 11.5),
        );
    }
  }

  Widget _trailing(BuildContext context, colors) {
    if (item.isActive) {
      return TapScale(
        onTap: () => BackgroundDownloadManager.instance.cancel(item.jobId),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: colors.shadowDark,
                offset: const Offset(2, 2),
                blurRadius: 4,
              ),
              BoxShadow(
                color: colors.shadowLight,
                offset: const Offset(-2, -2),
                blurRadius: 4,
              ),
            ],
          ),
          child: Icon(
            Icons.close_rounded,
            size: 16,
            color: colors.textSecondary,
          ),
        ),
      );
    }
    if (item.stage == BgStage.success) {
      return TapScale(
        onTap: () {
          if (item.folderPath != null) Process.run('open', [item.folderPath!]);
          BackgroundDownloadManager.instance.dismiss(item.jobId);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: colors.shadowDark,
                offset: const Offset(2, 2),
                blurRadius: 4,
              ),
              BoxShadow(
                color: colors.shadowLight,
                offset: const Offset(-2, -2),
                blurRadius: 4,
              ),
            ],
          ),
          child: Text(
            'View',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    return TapScale(
      onTap: () => BackgroundDownloadManager.instance.dismiss(item.jobId),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: colors.shadowDark,
              offset: const Offset(2, 2),
              blurRadius: 4,
            ),
            BoxShadow(
              color: colors.shadowLight,
              offset: const Offset(-2, -2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Icon(Icons.close_rounded, size: 16, color: colors.textSecondary),
      ),
    );
  }
}
