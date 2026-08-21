import 'package:flutter/material.dart';

enum AppThemeMode { light, dark }

class NeoColors {
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color textFaint;
  final Color shadowLight;
  final Color shadowDark;
  final Color accent;
  final Color accentSecondary;
  final Color videoStart;
  final Color videoEnd;
  final Color audioStart;
  final Color audioEnd;

  const NeoColors({
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.textFaint,
    required this.shadowLight,
    required this.shadowDark,
    required this.accent,
    required this.accentSecondary,
    required this.videoStart,
    required this.videoEnd,
    required this.audioStart,
    required this.audioEnd,
  });

  static const light = NeoColors(
    background: Color(0xFFE8ECF1),
    surface: Color(0xFFE8ECF1),
    textPrimary: Color(0xFF2D3436),
    textSecondary: Color(0xFF4A5259),
    textFaint: Color(0xFF8A94A0),
    shadowLight: Color(0xFFFFFFFF),
    shadowDark: Color(0xFFA3B1C6),
    accent: Color(0xFF7F5AF0),
    accentSecondary: Color(0xFFEC4899),
    videoStart: Color(0xFF7F5AF0),
    videoEnd: Color(0xFF5A3FC0),
    audioStart: Color(0xFFEC4899),
    audioEnd: Color(0xFFF97316),
  );

  static const dark = NeoColors(
    background: Color(0xFF23262E),
    surface: Color(0xFF23262E),
    textPrimary: Color(0xFFE4E6EB),
    textSecondary: Color(0xFFB0B4BC),
    textFaint: Color(0xFF6E7280),
    shadowLight: Color(0xFF2E323C),
    shadowDark: Color(0xFF15171C),
    accent: Color(0xFF9B7FF5),
    accentSecondary: Color(0xFFEC4899),
    videoStart: Color(0xFF9B7FF5),
    videoEnd: Color(0xFF6D4FD1),
    audioStart: Color(0xFFEC4899),
    audioEnd: Color(0xFFF97316),
  );

  static NeoColors of(AppThemeMode mode) =>
      mode == AppThemeMode.light ? light : dark;
}
