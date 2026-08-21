import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double blur;
  final List<BoxShadow>? shadows;
  final Gradient? fillGradient;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.blur = 18,
    this.shadows,
    this.fillGradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadows ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: AppColors.accentCyan.withValues(alpha: 0.06),
                blurRadius: 40,
                offset: const Offset(0, 0),
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: fillGradient ??
                  const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.glassFill, Color(0x0DFFFFFF)],
                  ),
              border: Border.all(color: AppColors.glassStroke, width: 1.2),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
