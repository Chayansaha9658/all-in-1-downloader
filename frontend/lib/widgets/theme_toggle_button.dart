import 'package:flutter/material.dart';

import '../services/theme_controller.dart';
import 'neomorphic_container.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final isLight = ThemeController.instance.isLight;
        final colors = ThemeController.instance.colors;
        return GestureDetector(
          onTap: () => ThemeController.instance.toggle(),
          child: NeomorphicContainer(
            padding: const EdgeInsets.all(10),
            borderRadius: BorderRadius.circular(999),
            style: NeoStyle.raised,
            intensity: 4,
            child: Icon(
              isLight ? Icons.wb_sunny_rounded : Icons.nightlight_round,
              color: colors.accent,
              size: 20,
            ),
          ),
        );
      },
    );
  }
}
