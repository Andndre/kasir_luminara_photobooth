import 'package:shared_preferences/shared_preferences.dart';

class SettingsPreferences {
  static const String keyMidtransEnabled = 'is_midtrans_enabled';

  static Future<bool> isMidtransEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyMidtransEnabled) ?? false;
  }

  static Future<void> setMidtransEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyMidtransEnabled, value);
  }
}
