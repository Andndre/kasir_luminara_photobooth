import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/constants/app_mode.dart';

class AppState extends ChangeNotifier {
  AppMode? _mode;
  ThemeMode _themeMode = ThemeMode.light;
  
  AppMode? get mode => _mode;
  ThemeMode get themeMode => _themeMode;
  bool get hasMode => _mode != null;

  void setMode(AppMode mode) {
    _mode = mode;
    notifyListeners();
  }

  void setThemeMode(ThemeMode themeMode) {
    _themeMode = themeMode;
    notifyListeners();
  }
}
