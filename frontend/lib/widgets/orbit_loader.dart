import 'dart:math';

import 'package:flutter/material.dart';

import '../services/theme_controller.dart';

class OrbitLoader extends StatefulWidget {
  final double size;

  const OrbitLoader({super.key, this.size = 26});

  @override
  State<OrbitLoader> createState() => _OrbitLoaderState();
}

class _OrbitLoaderState extends State<OrbitLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ThemeController.instance.colors;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _OrbitPainter(
              progress: _controller.value,
              accent: colors.accent,
              secondary: colors.videoStart,
            ),
          );
        },
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  final double progress;
  final Color accent;
  final Color secondary;

  _OrbitPainter({
    required this.progress,
    required this.accent,
    required this.secondary,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final ringRadius = size.width / 2 - 3;

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: pi * 2,
        transform: GradientRotation(progress * pi * 2),
        colors: [Colors.transparent, accent, secondary, Colors.transparent],
        stops: const [0.0, 0.35, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: ringRadius));

    canvas.drawCircle(center, ringRadius, arcPaint);

    final satelliteAngle = progress * pi * 2;
    final satelliteCenter = Offset(
      center.dx + ringRadius * cos(satelliteAngle),
      center.dy + ringRadius * sin(satelliteAngle),
    );

    final satellitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(satelliteCenter, 2.6, satellitePaint);

    final pulse = 0.55 + 0.45 * sin(progress * pi * 2);
    final corePaint = Paint()
      ..color = accent.withValues(alpha: pulse)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, size.width * 0.14, corePaint);
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.accent != accent;
}
