import 'package:flutter/material.dart';
import 'package:kasir/core/constants/app_mode.dart';

class AppState extends ChangeNotifier {
  AppMode? _mode;
  
  AppMode? get mode => _mode;
  bool get hasMode => _mode != null;

  void setMode(AppMode mode) {
    _mode = mode;
    notifyListeners();
  }
}
