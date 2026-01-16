import 'package:intl/intl.dart';
import 'package:luminara_photobooth/core/data/db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class Log {
  final DateTime timestamp;
  final String message;
  final bool isError;

  Log({required this.timestamp, required this.message, this.isError = false});

  @override
  String toString() {
    return 'Log: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp)} - $message';
  }

  Map<String, Object?> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'message': message,
      'is_error': isError ? 1 : 0,
    };
  }

  factory Log.fromMap(Map<String, Object?> map) {
    return Log(
      timestamp: DateTime.parse(map['timestamp'] as String),
      message: map['message'] as String,
      isError: (map['is_error'] as int) == 1,
    );
  }

  static Future<void> insertLog(String message, {bool isError = false}) async {
    final db = await getDatabase();
    await db.insert(
      'logs',
      Log(timestamp: DateTime.now(), message: message).toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Log>> getAllLogs() async {
    final db = await getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('logs');
    return List.generate(maps.length, (i) {
      return Log.fromMap(maps[i]);
    });
  }
}
