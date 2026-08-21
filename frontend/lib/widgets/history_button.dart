import 'package:flutter/material.dart';

import '../services/background_download_manager.dart';
import '../services/theme_controller.dart';
import 'neomorphic_container.dart';

class HistoryButton extends StatelessWidget {
  final VoidCallback onTap;

  const HistoryButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: BackgroundDownloadManager.instance,
      builder: (context, _) {
        final count = BackgroundDownloadManager.instance.activeCount;
        final colors = ThemeController.instance.colors;
        return GestureDetector(
          onTap: onTap,
          child: NeomorphicContainer(
            padding: const EdgeInsets.all(8),
            borderRadius: BorderRadius.circular(999),
            intensity: 4,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.download_rounded,
                  color: colors.textPrimary,
                  size: 18,
                ),
                if (count > 0)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: colors.videoStart,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
