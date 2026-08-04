import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

/// One row of the in-app diagnostic log (`logs` table).
class LogEntry extends Equatable {
  final DateTime timestamp;
  final String message;
  final bool isError;

  const LogEntry({
    required this.timestamp,
    required this.message,
    this.isError = false,
  });

  /// Column names are frozen — see `logs` table in `db.dart`.
  /// `is_error` is an INTEGER column, hence the 1/0 rather than a bool.
  Map<String, Object?> toMap() => {
    'timestamp': timestamp.toIso8601String(),
    'message': message,
    'is_error': isError ? 1 : 0,
  };

  factory LogEntry.fromMap(Map<String, Object?> map) => LogEntry(
    timestamp: DateTime.parse(map['timestamp'] as String),
    message: map['message'] as String,
    isError: (map['is_error'] as int? ?? 0) == 1,
  );

  @override
  String toString() =>
      'LogEntry: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp)} - $message';

  @override
  List<Object?> get props => [timestamp, message, isError];
}
