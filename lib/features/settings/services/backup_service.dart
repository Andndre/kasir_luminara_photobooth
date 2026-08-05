import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/core/data/db.dart';
import 'package:luminara_photobooth/core/services/cloud_api.dart';
import 'package:luminara_photobooth/core/services/sync_service.dart';

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

  /// Serialises every backed-up table. Separate from [export] so the format can
  /// be tested without driving a file picker.
  @visibleForTesting
  static Future<String> buildBackupJson() async {
    final db = await getDatabase();

    final tables = <String, Object?>{};
    for (final table in _backedUpTables) {
      tables[table] = await db.query(table);
    }

    return const JsonEncoder.withIndent('  ').convert({
      'version': _backupVersion,
      'created_at': DateTime.now().toIso8601String(),
      'tables': tables,
    });
  }

  /// Validates [rawJson] and swaps it in atomically. Throws [FormatException]
  /// on anything it doesn't recognise, before touching the database.
  @visibleForTesting
  static Future<void> applyBackupJson(String rawJson) async {
    final Object? decoded;
    try {
      decoded = json.decode(rawJson);
    } on FormatException {
      throw const FormatException('File backup tidak dikenali');
    }

    if (decoded is! Map) {
      throw const FormatException('File backup tidak dikenali');
    }

    final tables = decoded['tables'];
    if (decoded['version'] == null || tables is! Map) {
      throw const FormatException('File backup tidak dikenali');
    }

    // Read and validate every row before touching the database, so a bad file
    // is rejected while the existing data is still intact.
    final rows = <String, List<Map<String, Object?>>>{};
    for (final table in _restoredTables) {
      final value = tables[table];
      if (value != null && value is! List) {
        throw FormatException('Tabel "$table" dalam backup tidak valid');
      }
      rows[table] = ((value as List?) ?? const [])
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

      // Nisan yang tertinggal menunjuk ke dunia yang baru saja diganti. Kalau
      // dibiarkan, sync berikutnya akan menghapus baris di server yang justru
      // baru saja dipulihkan ke sini.
      await txn.delete('pending_deletes');
    });
  }

  /// Writes every table to a JSON file the user picks. Returns its path.
  static Future<Result<String>> export() =>
      runCatching('Gagal membuat backup', () async {
        final json = await buildBackupJson();

        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final fileName = 'luminara_backup_$timestamp.json';
        final bytes = utf8.encode(json);

        // file_picker's saveFile has opposite contracts per platform:
        //
        //   mobile  — `bytes` is REQUIRED (it throws ArgumentError without
        //             them), the plugin writes the file through the SAF URI
        //             itself, and returns a display path we must not write to.
        //   desktop — `bytes` is ignored; it only returns the chosen path and
        //             we do the writing.
        //
        // Passing no bytes on Android is what made backup fail there.
        final isMobile = Platform.isAndroid || Platform.isIOS;

        final path = await FilePicker.platform.saveFile(
          dialogTitle: 'Simpan Backup',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: const ['json'],
          bytes: isMobile ? bytes : null,
        );

        if (path == null) throw const BackupCancelled();

        if (!isMobile) {
          await File(path).writeAsBytes(bytes);
        }

        AppLog.info('Backup tersimpan: $path');
        return path;
      });

  /// Replaces the current data with a backup file's contents.
  ///
  /// The whole restore runs in one SQL transaction: previously it deleted
  /// everything first and inserted row by row, so a malformed file part-way
  /// through left the device with no data at all and nothing to roll back to.
  static Future<Result<void>> import() =>
      runCatching('Gagal memulihkan backup', () async {
        // Android resolves the extension filter through MimeTypeMap, which has
        // no entry for "json" on many builds. The filter then comes back empty
        // and the picker either errors with "Unsupported filter" or hides the
        // backup file. The content is validated below regardless, so on mobile
        // we let the user pick anything.
        final isMobile = Platform.isAndroid || Platform.isIOS;

        final picked = await FilePicker.platform.pickFiles(
          type: isMobile ? FileType.any : FileType.custom,
          allowedExtensions: isMobile ? null : const ['json'],
          allowMultiple: false,
        );

        final filePath = picked?.files.singleOrNull?.path;
        if (filePath == null) throw const BackupCancelled();

        await applyBackupJson(await File(filePath).readAsString());

        AppLog.info('Restore selesai dari $filePath');
        dataRefresh.invalidate();
      });

  /// Pulls this account's data down from luminarabali.com and swaps it in —
  /// the "ganti perangkat" path.
  ///
  /// Reuses [applyBackupJson] rather than parsing a second format: the server's
  /// `/api/pos/restore` deliberately answers in the backup file layout, so
  /// there is only ever one restore code path to get wrong.
  static Future<Result<void>> restoreFromCloud() async {
    switch (await const CloudApi().restoreJson()) {
      case Err(:final message, :final error, :final stackTrace):
        return Err(message, error, stackTrace);

      case Ok(value: final rawJson):
        return runCatching('Gagal memulihkan dari server', () async {
          await applyBackupJson(rawJson);

          // Baris ini baru saja datang *dari* server, jadi menandainya belum
          // tersinkron akan mendorong seluruh riwayat kembali ke sana tanpa
          // guna. Kursor penukaran ikut direset karena datanya sudah termuat.
          final db = await getDatabase();
          await db.update('transactions', {
            'synced_at': DateTime.now().toIso8601String(),
          });
          await SyncService().reset();

          AppLog.info('Restore selesai dari server');
          dataRefresh.invalidate();
        });
    }
  }
}
