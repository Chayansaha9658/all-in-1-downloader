import 'package:flutter/material.dart';

import '../services/theme_controller.dart';

enum NeoStyle { raised, pressed, flat }

class NeomorphicContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final NeoStyle style;
  final double intensity;

  const NeomorphicContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.style = NeoStyle.raised,
    this.intensity = 6,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final colors = ThemeController.instance.colors;
        final shadows = style == NeoStyle.flat
            ? <BoxShadow>[]
            : <BoxShadow>[
                BoxShadow(
                  color: colors.shadowDark,
                  offset: Offset(intensity, intensity),
                  blurRadius: intensity * 2.4,
                  spreadRadius: style == NeoStyle.pressed ? -2 : 0,
                ),
                BoxShadow(
                  color: colors.shadowLight,
                  offset: Offset(-intensity, -intensity),
                  blurRadius: intensity * 2.4,
                  spreadRadius: style == NeoStyle.pressed ? -2 : 0,
                ),
              ];
        return Container(
          padding: padding,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: borderRadius,
            boxShadow: shadows,
          ),
          child: child,
        );
      },
    );
  }
}
