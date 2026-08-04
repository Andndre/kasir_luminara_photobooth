import 'package:sqflite/sqflite.dart';

import '../../domain/dashboard_stats.dart';
import '../../domain/transaction_status.dart';
import '../db.dart';
import '../result.dart';

/// Aggregate counts for the home dashboard.
class StatisticsRepository {
  const StatisticsRepository();

  Future<Result<DashboardStats>>
  today() => runCatching('Gagal memuat statistik', () async {
    final db = await getDatabase();
    final now = DateTime.now();
    // created_at is an ISO-8601 string, so a date prefix match is enough.
    final todayPrefix =
        '${DateTime(now.year, now.month, now.day).toIso8601String().substring(0, 10)}%';

    Future<int> count(String sql, [List<Object?> args = const []]) async =>
        Sqflite.firstIntValue(await db.rawQuery(sql, args)) ?? 0;

    return DashboardStats(
      todayIncome: await count(
        'SELECT COALESCE(SUM(total_price), 0) FROM transactions WHERE created_at LIKE ?',
        [todayPrefix],
      ),
      todayTransactions: await count(
        'SELECT COUNT(*) FROM transactions WHERE created_at LIKE ?',
        [todayPrefix],
      ),
      queueCount: await count(
        'SELECT COUNT(*) FROM transactions WHERE status = ?',
        [TransactionStatus.paid.dbValue],
      ),
      productCount: await count('SELECT COUNT(*) FROM products'),
    );
  });
}
