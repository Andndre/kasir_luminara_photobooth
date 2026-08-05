import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Who this installation is, as far as the server is concerned.
///
/// Dipisah dari [AuthService] karena umurnya berbeda: token ikut akun dan
/// hilang saat logout, sedangkan id ini melekat pada instalasi. Kalau ikut
/// dihapus saat logout, satu perangkat akan terlihat seperti perangkat baru
/// setiap kali masuk lagi — dan sewa peran kasir miliknya sendiri jadi
/// terkunci oleh dirinya yang lama.
class DeviceIdentity {
  const DeviceIdentity._();

  static const _keyId = 'device_id';
  static const _keyName = 'device_name';

  static String? _cachedId;

  /// Stable per install. Dibuat sekali, lalu tidak pernah berubah.
  static Future<String> id() async {
    final cached = _cachedId;
    if (cached != null) return cached;

    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_keyId);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_keyId, id);
    }
    return _cachedId = id;
  }

  /// Nama yang dilihat manusia di dialog "sedang dipakai perangkat lain".
  ///
  /// Harus bisa dikenali orang yang berdiri di venue, jadi bisa diubah user.
  /// Bawaannya nama platform, yang cukup untuk membedakan HP dari komputer
  /// kasir tapi tidak untuk membedakan dua HP.
  static Future<String> name() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyName) ?? _defaultName;
  }

  static Future<void> setName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(_keyName);
      return;
    }
    await prefs.setString(_keyName, trimmed);
  }

  static String get _defaultName => switch (Platform.operatingSystem) {
    'android' => 'HP Android',
    'ios' => 'iPhone',
    'windows' => 'Komputer Windows',
    'linux' => 'Komputer Linux',
    'macos' => 'Mac',
    final other => other,
  };
}
