import 'package:flutter/material.dart';

class TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final double hoverScale;

  const TapScale({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.94,
    this.hoverScale = 1.05,
  });

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  bool _pressed = false;
  bool _hovering = false;

  double get _scale {
    if (_pressed) return widget.pressedScale;
    if (_hovering) return widget.hoverScale;
    return 1.0;
  }

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}
