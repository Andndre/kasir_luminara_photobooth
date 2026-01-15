import 'package:shared_preferences/shared_preferences.dart';

class VerifierPreferences {
  static const String _keyServerIp = 'verifier_server_ip';
  static const String _keyServerPort = 'verifier_server_port';

  static Future<void> saveServerAddress(String ip, int port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServerIp, ip);
    await prefs.setInt(_keyServerPort, port);
  }

  static Future<Map<String, dynamic>?> getServerAddress() async {
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString(_keyServerIp);
    final port = prefs.getInt(_keyServerPort);

    if (ip != null && port != null) {
      return {'ip': ip, 'port': port};
    }
    return null;
  }

  static Future<void> clearServerAddress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyServerIp);
    await prefs.remove(_keyServerPort);
  }
}
