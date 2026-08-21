import 'dart:math';

import 'package:flutter/material.dart';

import '../services/theme_controller.dart';

class ProgressRing extends StatelessWidget {
  final double? progress;
  final double size;

  const ProgressRing({super.key, required this.progress, this.size = 110});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final colors = ThemeController.instance.colors;
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size, size),
                painter: _RingPainter(
                  progress: progress,
                  trackColor: colors.shadowDark.withValues(alpha: 0.35),
                  startColor: colors.videoStart,
                  endColor: colors.accent,
                ),
              ),
              Text(
                progress != null
                    ? '${(progress! * 100).clamp(0, 100).toStringAsFixed(0)}%'
                    : '--',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double? progress;
  final Color trackColor;
  final Color startColor;
  final Color endColor;

  _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.startColor,
    required this.endColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 6;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawCircle(center, radius, trackPaint);

    final sweep = 2 * pi * (progress ?? 0.12).clamp(0.0, 1.0);
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [startColor, endColor],
        startAngle: 0,
        endAngle: pi * 1.6,
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweep == 0 ? 0.001 : sweep,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
