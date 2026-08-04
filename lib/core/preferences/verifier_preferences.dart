import 'package:luminara_photobooth/core/domain/server_address.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Last server the verifier was paired with, so it can reconnect on launch.
class VerifierPreferences {
  const VerifierPreferences._();

  // Persisted keys — existing installs hold values under these exact names.
  static const String _keyServerIp = 'verifier_server_ip';
  static const String _keyServerPort = 'verifier_server_port';

  /// Verifier memakai luminarabali.com, bukan kasir di LAN. Kunci baru; kalau
  /// belum ada, artinya instalasi lama yang masih LAN — jadi default false
  /// menjaga perilaku yang sudah berjalan.
  static const String _keyUseCloud = 'verifier_use_cloud';

  static Future<void> setUseCloud(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseCloud, value);
  }

  static Future<bool> useCloud() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyUseCloud) ?? false;
  }

  static Future<void> saveServerAddress(ServerAddress address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServerIp, address.host);
    await prefs.setInt(_keyServerPort, address.port);
  }

  /// Returns null when nothing has been paired yet.
  static Future<ServerAddress?> getServerAddress() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString(_keyServerIp);
    if (host == null) return null;

    return ServerAddress(
      host,
      prefs.getInt(_keyServerPort) ?? ServerAddress.defaultPort,
    );
  }

  static Future<void> clearServerAddress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyServerIp);
    await prefs.remove(_keyServerPort);
  }
}
