import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/core/data/db.dart';
import 'package:luminara_photobooth/app/app.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';

void main(List<String> args) {
  if (runWebViewTitleBarWidget(args)) {
    return;
  }

  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize Database
      // (Pastikan kode hapus DB di getDatabase() sudah dimatikan agar data aman)
      await getDatabase();

      Bloc.observer = AppBlocObserver();

      // Request permissions only on Mobile
      if (Platform.isAndroid || Platform.isIOS) {
        await [
          Permission.bluetooth,
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          // Lokasi hanya untuk Android: di sana pemindaian BLE menolak jalan
          // tanpa izin lokasi. iOS tidak memerlukannya, dan memintanya di sana
          // justru mematikan aplikasi — Info.plist tidak punya
          // NSLocationWhenInUseUsageDescription, dan Apple menghentikan proses
          // yang meminta lokasi tanpa deskripsi itu.
          if (Platform.isAndroid) Permission.location,
        ].request();
      }

      await initializeDateFormatting('id_ID', null);

      _setupErrorHandling();

      runApp(const MyApp());
    },
    (error, stack) {
      AppLog.error('GLOBAL ERROR: $error');
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
