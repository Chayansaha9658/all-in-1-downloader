import 'package:flutter/material.dart';

import '../services/backend_config_service.dart';
import '../services/theme_controller.dart';
import '../sheets/backend_settings_sheet.dart';
import 'neomorphic_container.dart';
import 'tap_scale.dart';

class BackendSetupBanner extends StatelessWidget {
  const BackendSetupBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: BackendConfigService.instance,
      builder: (context, _) {
        final service = BackendConfigService.instance;
        if (!service.isLoaded || service.hasCustomUrl) {
          return const SizedBox.shrink();
        }
        final colors = ThemeController.instance.colors;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TapScale(
            onTap: () => showBackendSettingsSheet(context),
            child: NeomorphicContainer(
              padding: const EdgeInsets.all(14),
              borderRadius: BorderRadius.circular(18),
              child: Row(
                children: [
                  Icon(Icons.dns_rounded, color: colors.accent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Set your backend server IP',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tap here to connect this app to your backend',
                          style: TextStyle(
                            color: colors.textFaint,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: colors.textFaint),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
