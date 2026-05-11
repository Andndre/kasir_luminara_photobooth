import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:luminara_photobooth/core/data/db.dart';

class BackupService {
  /// Export semua data ke file JSON
  /// Return: path file backup, atau null kalau gagal
  static Future<String?> exportBackup() async {
    try {
      final db = await getDatabase();

      // Ambil semua data dari setiap tabel
      final products = await db.query('products');
      final transactions = await db.query('transactions');
      final transactionItems = await db.query('transaction_items');
      final logs = await db.query('logs');
      final dailyQueueCounter = await db.query('daily_queue_counter');

      // Susun jadi JSON object
      final backupData = {
        'version': '1.0',
        'created_at': DateTime.now().toIso8601String(),
        'tables': {
          'products': products,
          'transactions': transactions,
          'transaction_items': transactionItems,
          'logs': logs,
          'daily_queue_counter': dailyQueueCounter,
        },
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);

      // Simpan ke Downloads folder
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final defaultFileName = 'luminara_backup_$timestamp.json';

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Simpan Backup',
        fileName: defaultFileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        final file = File(result);
        await file.writeAsString(jsonString);
        return result;
      }

      return null;
    } catch (e) {
      print('Backup error: $e');
      return null;
    }
  }
}
