import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/constants/app_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  AppMode? _mode;
  ThemeMode _themeMode = ThemeMode.light;
  static const String _themeKey = 'theme_mode';
  
  AppMode? get mode => _mode;
  ThemeMode get themeMode => _themeMode;
  bool get hasMode => _mode != null;

  AppState() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_themeKey) ?? false;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void setMode(AppMode mode) {
    _mode = mode;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    _themeMode = themeMode;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, themeMode == ThemeMode.dark);
  }
}
