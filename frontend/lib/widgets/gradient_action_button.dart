import 'package:flutter/material.dart';

import '../services/theme_controller.dart';
import 'tap_scale.dart';

class GradientActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color colorStart;
  final Color colorEnd;
  final VoidCallback? onTap;

  const GradientActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.colorStart,
    required this.colorEnd,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final colors = ThemeController.instance.colors;
        return TapScale(
          onTap: onTap,
          child: Opacity(
            opacity: disabled ? 0.45 : 1,
            child: Container(
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colorStart, colorEnd],
                ),
                boxShadow: disabled
                    ? []
                    : [
                        BoxShadow(
                          color: colors.shadowDark,
                          offset: const Offset(5, 5),
                          blurRadius: 12,
                        ),
                        BoxShadow(
                          color: colors.shadowLight,
                          offset: const Offset(-5, -5),
                          blurRadius: 12,
                        ),
                      ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
