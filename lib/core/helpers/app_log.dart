import 'package:flutter/foundation.dart';

import '../data/db.dart';
import '../domain/log_entry.dart';

/// Diagnostic log, persisted to the `logs` table and viewable in Settings.
///
/// Every method swallows its own errors: logging is called from `catch` blocks
/// and error handlers, so a failure here must never mask the original problem
/// or throw out of a handler. Failures fall back to the debug console.
class AppLog {
  const AppLog._();

  static Future<void> info(String message) => _write(message, isError: false);

  static Future<void> error(String message) => _write(message, isError: true);

  static Future<void> _write(String message, {required bool isError}) async {
    debugPrint(isError ? 'ERROR: $message' : message);
    try {
      final db = await getDatabase();
      await db.insert(
        'logs',
        LogEntry(
          timestamp: DateTime.now(),
          message: message,
          isError: isError,
        ).toMap(),
      );
    } catch (e) {
      // ponytail: console-only fallback. Nothing sensible to do if the log
      // table itself is unwritable, and throwing here would hide the real bug.
      debugPrint('AppLog write failed: $e');
    }
  }

  /// Newest first. Returns empty on failure rather than throwing — the log
  /// viewer degrades to "no entries" instead of crashing.
  static Future<List<LogEntry>> recent({int limit = 500}) async {
    try {
      final db = await getDatabase();
      final rows = await db.query(
        'logs',
        orderBy: 'timestamp DESC',
        limit: limit,
      );
      return rows.map(LogEntry.fromMap).toList();
    } catch (e) {
      debugPrint('AppLog read failed: $e');
      return const [];
    }
  }

  static Future<void> clear() async {
    try {
      final db = await getDatabase();
      await db.delete('logs');
    } catch (e) {
      debugPrint('AppLog clear failed: $e');
    }
  }
}
