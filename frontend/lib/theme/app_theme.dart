import 'package:flutter/material.dart';

class AppColors {
  static const bgTop = Color(0xFF140B33);
  static const bgMid = Color(0xFF1E1240);
  static const bgBottom = Color(0xFF07040F);

  static const videoStart = Color(0xFF7F5AF0);
  static const videoEnd = Color(0xFF2CB1FF);

  static const audioStart = Color(0xFFFF4FA3);
  static const audioEnd = Color(0xFFFF9A56);

  static const accentCyan = Color(0xFF2CE0F5);

  static const glassFill = Color(0x1AFFFFFF);
  static const glassStroke = Color(0x40FFFFFF);

  static const textPrimary = Color(0xFFF6F4FF);
  static const textSecondary = Color(0xFFAFA7D6);
  static const textFaint = Color(0xFF7A72A6);
}

class AppGradients {
  static const background = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.bgTop, AppColors.bgMid, AppColors.bgBottom],
  );

  static const video = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.videoStart, AppColors.videoEnd],
  );

  static const audio = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.audioStart, AppColors.audioEnd],
  );

  static const glassStroke = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x55FFFFFF), Color(0x0DFFFFFF)],
  );
}

class AppTextStyles {
  static const heading = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: 0.2,
    height: 1.15,
  );

  static const subheading = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    letterSpacing: 0.3,
  );

  static const buttonLabel = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: 0.2,
  );

  static const sheetTitle = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
}
