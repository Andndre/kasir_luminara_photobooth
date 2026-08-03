import 'package:shared_preferences/shared_preferences.dart';

class PrinterPreferences {
  // ponytail: esc_pos_utils cuma punya mm58 & mm80, jadi cukup bool.
  static String _keyPaper(String mac) => 'printer_paper_mm80_$mac';
  static const String _keyLastMac = 'printer_last_mac';

  static Future<bool> isPaperMm80(String mac) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyPaper(mac)) ?? false;
  }

  static Future<void> setPaperMm80(String mac, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPaper(mac), value);
  }

  /// MAC printer terakhir yang berhasil dihubungkan, dipakai untuk
  /// menentukan ukuran kertas setelah aplikasi dibuka ulang.
  static Future<void> setLastMac(String mac) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastMac, mac);
  }

  static Future<String?> getLastMac() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastMac);
  }
}
