import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/core/data/db.dart';

/// Backup file format version. Bump only for a breaking change to the layout;
/// the reader below accepts anything with a `tables` map.
const _backupVersion = '1.0';

/// Tables written to the backup, and the JSON keys they live under.
///
/// These strings are the file format — old backup files on customers' disks
/// use them. Adding a table is safe; renaming one is not.
const _backedUpTables = [
  'products',
  'transactions',
  'transaction_items',
  'logs',
  'daily_queue_counter',
];

/// Tables cleared and rewritten on restore. `logs` is deliberately excluded:
/// the diagnostic log of *this* device is more useful than the backup's.
const _restoredTables = [
  'products',
  'transactions',
  'transaction_items',
  'daily_queue_counter',
];

/// The user cancelled the file picker. Not an error, but not a success either.
class BackupCancelled implements Exception {
  const BackupCancelled();
  @override
  String toString() => 'Dibatalkan';
}

class BackupService {
  const BackupService._();

  /// Writes every table to a JSON file the user picks. Returns its path.
  static Future<Result<String>> export() =>
      runCatching('Gagal membuat backup', () async {
        final db = await getDatabase();

        final tables = <String, Object?>{};
        for (final table in _backedUpTables) {
          tables[table] = await db.query(table);
        }

        final json = const JsonEncoder.withIndent('  ').convert({
          'version': _backupVersion,
          'created_at': DateTime.now().toIso8601String(),
          'tables': tables,
        });

        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final path = await FilePicker.platform.saveFile(
          dialogTitle: 'Simpan Backup',
          fileName: 'luminara_backup_$timestamp.json',
          type: FileType.custom,
          allowedExtensions: const ['json'],
        );

        if (path == null) throw const BackupCancelled();

        await File(path).writeAsString(json);
        return path;
      });

  /// Replaces the current data with a backup file's contents.
  ///
  /// The whole restore runs in one SQL transaction: previously it deleted
  /// everything first and inserted row by row, so a malformed file part-way
  /// through left the device with no data at all and nothing to roll back to.
  static Future<Result<void>> import() =>
      runCatching('Gagal memulihkan backup', () async {
        final picked = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['json'],
          allowMultiple: false,
        );

        final filePath = picked?.files.singleOrNull?.path;
        if (filePath == null) throw const BackupCancelled();

        final decoded =
            json.decode(await File(filePath).readAsString())
                as Map<String, dynamic>;

        final tables = decoded['tables'];
        if (decoded['version'] == null || tables is! Map) {
          throw const FormatException('File backup tidak dikenali');
        }

        // Read and validate every row before touching the database, so a bad
        // file is rejected while the existing data is still intact.
        final rows = <String, List<Map<String, Object?>>>{};
        for (final table in _restoredTables) {
          rows[table] = ((tables[table] as List?) ?? const [])
              .map((row) => Map<String, Object?>.from(row as Map))
              .toList();
        }

        final db = await getDatabase();
        await db.transaction((txn) async {
          // Children first: transaction_items references transactions.
          for (final table in _restoredTables.reversed) {
            await txn.delete(table);
          }
          for (final table in _restoredTables) {
            for (final row in rows[table]!) {
              await txn.insert(table, row);
            }
          }
        });

        AppLog.info('Restore selesai dari $filePath');
        dataRefresh.invalidate();
      });
}
