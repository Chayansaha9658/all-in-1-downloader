import 'package:flutter/material.dart';

import '../models/video_info.dart';
import '../services/theme_controller.dart';
import '../widgets/neomorphic_container.dart';
import '../widgets/tap_scale.dart';

Future<ResolutionChoice?> showResolutionPickerSheet(
  BuildContext context,
  List<ResolutionChoice> choices,
) {
  return showModalBottomSheet<ResolutionChoice>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _ResolutionPickerSheet(choices: choices),
  );
}

class _ResolutionPickerSheet extends StatelessWidget {
  final List<ResolutionChoice> choices;

  const _ResolutionPickerSheet({required this.choices});

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
                'Choose resolution',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'File size shown next to each video quality',
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 18),
              if (choices.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No resolutions found',
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: choices.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final choice = choices[index];
                      return TapScale(
                        onTap: () => Navigator.of(context).pop(choice),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: colors.background,
                            borderRadius: BorderRadius.circular(16),
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
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      colors.videoStart,
                                      colors.videoEnd,
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  choice.label,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                formatBytes(choice.estimatedBytes).isEmpty
                                    ? '—'
                                    : formatBytes(choice.estimatedBytes),
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 13.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: colors.textFaint,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
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
