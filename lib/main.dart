import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/core/data/db.dart';
import 'package:luminara_photobooth/app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Database (FFI for Windows/Linux)
  await getDatabase();
  
  Bloc.observer = AppBlocObserver();
  
  // Request permissions only on Mobile (Android/iOS)
  if (Platform.isAndroid || Platform.isIOS) {
    // Permission requests...
  }

  await initializeDateFormatting('id_ID', null);
  
  // Launch the main application directly
  runApp(const MyApp());
}