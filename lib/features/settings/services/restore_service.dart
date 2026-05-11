import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:luminara_photobooth/core/data/db.dart';

class RestoreService {
  /// Import data dari file JSON backup
  /// [onSuccess] callback yang dipanggil setelah restore berhasil (untuk trigger refresh UI)
  /// Return: true kalau berhasil
  static Future<bool> importBackup({VoidCallback? onSuccess}) async {
    try {
      // Pilih file backup
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return false;

      final filePath = result.files.single.path;
      if (filePath == null) return false;

      // Baca isi file
      final file = File(filePath);
      final jsonString = await file.readAsString();
      final backupData = json.decode(jsonString) as Map<String, dynamic>;

      // Validasi format backup
      if (!backupData.containsKey('version') ||
          !backupData.containsKey('tables')) {
        throw Exception('Invalid backup file format');
      }

      final db = await getDatabase();

      // Hapus semua data lama (kecuali logs opsional)
      await db.delete('transaction_items');
      await db.delete('transactions');
      await db.delete('products');
      await db.delete('daily_queue_counter');

      // Restore products
      final products = backupData['tables']['products'] as List;
      for (final product in products) {
        await db.insert('products', Map<String, dynamic>.from(product));
      }

      // Restore transactions
      final transactions = backupData['tables']['transactions'] as List;
      for (final tx in transactions) {
        await db.insert('transactions', Map<String, dynamic>.from(tx));
      }

      // Restore transaction_items
      final items = backupData['tables']['transaction_items'] as List;
      for (final item in items) {
        await db.insert('transaction_items', Map<String, dynamic>.from(item));
      }

      // Restore daily_queue_counter
      final counters = backupData['tables']['daily_queue_counter'] as List;
      for (final counter in counters) {
        await db.insert('daily_queue_counter', Map<String, dynamic>.from(counter));
      }

      // Trigger refresh callback
      onSuccess?.call();

      return true;
    } catch (e) {
      print('Restore error: $e');
      return false;
    }
  }
}
