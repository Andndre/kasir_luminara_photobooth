import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/core/data/db.dart';
import 'package:luminara_photobooth/app/app.dart';
import 'package:luminara_photobooth/core/services/background_service.dart';
import 'package:luminara_photobooth/model/log.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';

void main(List<String> args) {
  if (runWebViewTitleBarWidget(args)) {
    return;
  }

  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      if (Platform.isWindows) {
        await requestWindowsFirewallAccess(3000);
      }

      // Initialize Database
      // (Pastikan kode hapus DB di getDatabase() sudah dimatikan agar data aman)
      await getDatabase();

      // Initialize Background Service (Android/iOS)
      if (Platform.isAndroid || Platform.isIOS) {
        if (Platform.isAndroid) {
          final FlutterLocalNotificationsPlugin
          flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
          await flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.createNotificationChannel(
                const AndroidNotificationChannel(
                  notificationChannelId,
                  'Luminara Server Service',
                  description: 'Menjaga server tetap aktif di latar belakang.',
                  importance: Importance.low,
                ),
              );
        }
        await initializeBackgroundService();
      }

      Bloc.observer = AppBlocObserver();

      // Request permissions only on Mobile
      if (Platform.isAndroid || Platform.isIOS) {
        await [
          Permission.notification,
          Permission.bluetooth,
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.location,
        ].request();
      }

      await initializeDateFormatting('id_ID', null);

      _setupErrorHandling();

      runApp(const MyApp());
    },
    (error, stack) {
      Log.insertLog('GLOBAL ERROR: $error', isError: true);
      debugPrint('STACKTRACE: $stack');
    },
  );
}

void _setupErrorHandling() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FLUTTER ERROR: ${details.exception}');
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.red.shade50,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Terjadi Kesalahan UI!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 12),
              Text(details.exception.toString(), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  };
}

Future<void> requestWindowsFirewallAccess(int port) async {
  // Nama Rule yang akan muncul di Windows Firewall
  const String ruleName = "Luminara Photobooth Server";

  // Script PowerShell: Cek apakah rule sudah ada? Jika belum, buat baru.
  final String command =
      '''
    if (-not (Get-NetFirewallRule -DisplayName "$ruleName" -ErrorAction SilentlyContinue)) {
      New-NetFirewallRule -DisplayName "$ruleName" -Direction Inbound -LocalPort $port -Protocol TCP -Action Allow -Profile Any
    }
  ''';

  try {
    // Jalankan PowerShell dengan mode RunAs (Admin Trigger)
    await Process.run('powershell', [
      '-Command',
      'Start-Process',
      'powershell',
      '-ArgumentList',
      "'-NoProfile', '-Command', '$command'",
      '-Verb',
      'RunAs',
    ], runInShell: true);
    debugPrint("Request Firewall Access dikirim...");
  } catch (e) {
    Log.insertLog("Gagal meminta akses firewall: $e", isError: true);
  }
}
