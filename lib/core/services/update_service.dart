import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:luminara_photobooth/core/helpers/app_log.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Rilis yang lebih baru dari yang sedang berjalan.
class AppUpdate {
  final String version;
  final Uri url;
  const AppUpdate(this.version, this.url);
}

/// Memberi tahu kalau ada rilis baru. TIDAK memasangnya sendiri.
///
/// ponytail: memasang sendiri butuh izin REQUEST_INSTALL_PACKAGES + FileProvider
/// di Android, dan menjalankan installer lalu mematikan diri sendiri di Windows.
/// Keduanya bisa, tapi keduanya berarti aplikasi kasir boleh memasang berkas
/// yang baru saja diunduhnya sendiri — itu bukan sesuatu yang dipasang sambil
/// lalu. Untuk sekarang: kabari, lalu serahkan ke browser dan OS.
///
/// iOS tidak ada di daftar dan tidak bisa diadakan: tidak ada jalan bagi
/// aplikasi iOS untuk memasang aplikasi iOS. Di sana pembaruan datang lewat
/// TestFlight atau App Store, bukan dari kode ini.
class UpdateService {
  /// Repo-nya publik, jadi tanpa token. Ini juga TIDAK menyentuh
  /// luminarabali.com — permintaannya pergi ke GitHub, bukan menambah beban
  /// dari IP venue ke server sendiri.
  static const _releasesApi =
      'https://api.github.com/repos/Andndre/kasir_luminara_photobooth'
      '/releases/latest';

  /// Null kalau sudah paling baru, platformnya tidak dilayani, atau jaringannya
  /// bermasalah. Gagal memeriksa pembaruan tidak pernah cukup penting untuk
  /// mengganggu orang yang sedang melayani antrean.
  static Future<AppUpdate?> check() async {
    final suffix = assetSuffix;
    if (suffix == null) return null;

    try {
      final response = await http
          .get(Uri.parse(_releasesApi))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final latest = (body['tag_name'] as String? ?? '').replaceFirst('v', '');
      final current = (await PackageInfo.fromPlatform()).version;
      if (!isNewer(latest, current)) return null;

      for (final asset in (body['assets'] as List? ?? const []).whereType<Map>()) {
        final name = asset['name'] as String? ?? '';
        final url = asset['browser_download_url'] as String?;
        if (url != null && name.endsWith(suffix)) {
          return AppUpdate(latest, Uri.parse(url));
        }
      }
      return null;
    } catch (e) {
      AppLog.info('Gagal cek pembaruan: $e');
      return null;
    }
  }

  /// Akhiran nama berkas rilis untuk perangkat ini; null = tidak dilayani.
  ///
  /// ABI dibaca dari [Abi.current], bukan ditebak arm64: CI membangun tiga APK
  /// terpisah (`--split-per-abi`) dan APK dengan ABI yang salah gagal dipasang
  /// tanpa penjelasan yang bisa dibaca orang.
  @visibleForTesting
  static String? get assetSuffix {
    if (Platform.isWindows) return '.exe';
    if (!Platform.isAndroid) return null;

    final abi = Abi.current();
    if (abi == Abi.androidArm64) return 'arm64-v8a-release.apk';
    if (abi == Abi.androidArm) return 'armeabi-v7a-release.apk';
    if (abi == Abi.androidX64) return 'x86_64-release.apk';
    return null;
  }

  /// Versi yang tidak terbaca dianggap TIDAK lebih baru — kalau tag rilisnya
  /// suatu hari berbentuk lain, akibat terburuknya orang tidak diberi tahu,
  /// bukan disuruh mengunduh sesuatu yang lebih tua.
  @visibleForTesting
  static bool isNewer(String candidate, String current) {
    final a = _parts(candidate);
    final b = _parts(current);
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i] > b[i];
    }
    return false;
  }

  static List<int> _parts(String version) {
    final nums = version
        .split('.')
        .map((s) => int.tryParse(s.trim()) ?? 0)
        .toList();
    while (nums.length < 3) {
      nums.add(0);
    }
    return nums;
  }
}
