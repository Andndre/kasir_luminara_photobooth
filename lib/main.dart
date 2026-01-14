import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/core/data/db.dart';
import 'package:luminara_photobooth/app/app.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Database
    await getDatabase();

    Bloc.observer = AppBlocObserver();

    // Request permissions only on Mobile
    if (Platform.isAndroid || Platform.isIOS) {
      // Logic for permissions...
    }

    await initializeDateFormatting('id_ID', null);

    _setupErrorHandling();

    runApp(const MyApp());
  }, (error, stack) {
    debugPrint('GLOBAL ERROR: $error');
    debugPrint('STACKTRACE: $stack');
  });
}

void _setupErrorHandling() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FLUTTER ERROR: ${details.exception}');
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.red.shade50,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Terjadi Kesalahan UI!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const SizedBox(height: 12),
                Text(details.exception.toString(), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  };
}