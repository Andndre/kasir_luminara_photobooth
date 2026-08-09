import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:http/http.dart' as http;
import 'package:luminara_photobooth/core/helpers/app_log.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Rilis yang lebih baru dari yang sedang berjalan.
class AppUpdate {
  final String version;
  final Uri url;
  const AppUpdate(this.version, this.url);
}

/// Memeriksa, mengunduh, dan memasang rilis baru — tanpa keluar dari aplikasi.
///
/// Yang TIDAK bisa dihilangkan di kedua platform: layar konfirmasi milik sistem.
/// Android memunculkan dialog pemasang paket, Windows memunculkan UAC. Melewati
/// keduanya butuh hak yang hanya dimiliki pemilik perangkat terkelola, dan
/// aplikasi kasir tidak punya urusan meminta itu.
///
/// iOS tidak ada di sini dan tidak bisa diadakan: tidak ada jalan bagi aplikasi
/// iOS untuk memasang aplikasi iOS. Di sana pembaruan datang lewat TestFlight
/// atau App Store, bukan dari kode ini.
class UpdateService {
  static const _channel = MethodChannel('luminara/update');

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

  /// Mengunduh berkas rilis, melaporkan kemajuan 0..1 selama berjalan.
  ///
  /// Ditulis mengalir ke disk, bukan ditampung di memori dulu: APK-nya puluhan
  /// megabita dan yang mengunduh adalah HP kasir yang sedang memegang seluruh
  /// antrean hari itu.
  static Future<File> download(
    AppUpdate update, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
    await dir.create(recursive: true);
    // Nama berkasnya tetap: unduhan yang gagal separuh ditimpa percobaan
    // berikutnya, bukan menumpuk di penyimpanan sampai orang mengeluh penuh.
    final file = File('${dir.path}/${update.url.pathSegments.last}');

    final client = http.Client();
    try {
      final response = await client.send(http.Request('GET', update.url));
      if (response.statusCode != 200) {
        throw HttpException('Unduhan ditolak (${response.statusCode})');
      }

      final total = response.contentLength ?? 0;
      var received = 0;
      final sink = file.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) onProgress?.call(received / total);
        }
      } finally {
        await sink.close();
      }

      // Berkas separuh jalan lebih berbahaya daripada tidak ada berkas: di
      // Android ia gagal dipasang dengan pesan yang tidak menjelaskan apa pun.
      if (total > 0 && received != total) {
        await file.delete();
        throw const HttpException('Unduhan terputus sebelum selesai');
      }
      return file;
    } finally {
      client.close();
    }
  }

  /// Menyerahkan berkasnya ke pemasang milik sistem.
  ///
  /// Di Windows fungsi ini TIDAK kembali: installer Inno-nya menimpa berkas
  /// aplikasi yang sedang berjalan ini, jadi aplikasinya harus pergi lebih
  /// dulu. `/SILENT` menghilangkan wizard-nya, bukan UAC-nya.
  static Future<void> install(File file) async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod<void>('install', {'path': file.path});
      return;
    }
    await Process.start(
      file.path,
      ['/SILENT'],
      mode: ProcessStartMode.detached,
    );
    exit(0);
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
