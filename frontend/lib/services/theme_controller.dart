import 'package:flutter/foundation.dart';

import '../theme/neomorphic_theme.dart';

class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  AppThemeMode _mode = AppThemeMode.light;

  AppThemeMode get mode => _mode;
  bool get isLight => _mode == AppThemeMode.light;
  NeoColors get colors => NeoColors.of(_mode);

  void toggle() {
    _mode = _mode == AppThemeMode.light
        ? AppThemeMode.dark
        : AppThemeMode.light;
    notifyListeners();
  }
}
