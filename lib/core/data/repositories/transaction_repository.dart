import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;

import '../../domain/transaction.dart';
import '../../domain/transaction_status.dart';
import '../db.dart';
import '../result.dart';

/// Outcome of redeeming a ticket. Three distinct cases the caller must handle,
/// so they get three distinct types rather than a nullable-plus-bool.
sealed class RedeemOutcome {
  const RedeemOutcome();
}

final class RedeemedOk extends RedeemOutcome {
  final Transaction transaction;
  const RedeemedOk(this.transaction);
}

final class TicketNotFound extends RedeemOutcome {
  const TicketNotFound();
}

final class TicketAlreadyUsed extends RedeemOutcome {
  final Transaction transaction;
  const TicketAlreadyUsed(this.transaction);
}

/// The only place that touches `transactions`, `transaction_items` and
/// `daily_queue_counter`.
class TransactionRepository {
  const TransactionRepository();

  static final _queueDateFormat = DateFormat('yyyy-MM-dd');

  /// Max UUIDs per `IN (...)` batch in [_hydrate].
  static const _hydrateChunk = 500;

  /// Inserts the header, its items and the day's queue number in one atomic
  /// SQL transaction. Returns the assigned queue number.
  Future<Result<int>> create(Transaction transaction) =>
      runCatching('Gagal menyimpan transaksi', () async {
        final db = await getDatabase();
        late int queueNumber;
        await db.transaction((txn) async {
          final today = _queueDateFormat.format(DateTime.now());
          queueNumber = await _nextQueueNumber(txn, today);

          final row = transaction
              .copyWith(queueNumber: queueNumber, queueDate: today)
              .toMap();

          await txn.insert(
            'transactions',
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          for (final item in transaction.items) {
            await txn.insert('transaction_items', item.toMap(transaction.uuid));
          }
        });
        return queueNumber;
      });

  /// Reads and bumps today's counter. Must run inside the caller's SQL
  /// transaction so two concurrent sales can't take the same number.
  static Future<int> _nextQueueNumber(DatabaseExecutor db, String today) async {
    final rows = await db.query(
      'daily_queue_counter',
      where: 'date = ?',
      whereArgs: [today],
    );

    if (rows.isEmpty) {
      await db.insert('daily_queue_counter', {'date': today, 'last_number': 1});
      return 1;
    }

    final next = (rows.first['last_number'] as int) + 1;
    await db.update(
      'daily_queue_counter',
      {'last_number': next},
      where: 'date = ?',
      whereArgs: [today],
    );
    return next;
  }

  Future<Result<List<Transaction>>> all() =>
      runCatching('Gagal memuat transaksi', () async {
        final db = await getDatabase();
        final rows = await db.query('transactions', orderBy: 'created_at DESC');
        return _hydrate(db, rows);
      });

  /// Inclusive of both endpoints' full days.
  Future<Result<List<Transaction>>> byDateRange(DateTime start, DateTime end) =>
      runCatching('Gagal memuat transaksi', () async {
        final db = await getDatabase();
        final from = DateTime(start.year, start.month, start.day);
        final to = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
        final rows = await db.query(
          'transactions',
          where: 'created_at BETWEEN ? AND ?',
          whereArgs: [from.toIso8601String(), to.toIso8601String()],
          orderBy: 'created_at DESC',
        );
        return _hydrate(db, rows);
      });

  /// Unredeemed tickets, in the order they should be called at the booth.
  /// Legacy rows without a queue number sort last, by creation time.
  Future<Result<List<Transaction>>> pendingQueue() =>
      runCatching('Gagal memuat antrian', () async {
        final db = await getDatabase();
        final rows = await db.query(
          'transactions',
          where: 'status = ?',
          whereArgs: [TransactionStatus.paid.dbValue],
          orderBy: '''
            CASE WHEN queue_number IS NULL THEN 1 ELSE 0 END ASC,
            queue_date ASC,
            queue_number ASC,
            created_at ASC
          ''',
        );
        return _hydrate(db, rows);
      });

  /// Deletes locally and leaves a tombstone for the server.
  ///
  /// Tanpa nisan itu penghapusan tidak punya apa pun untuk dikirim — barisnya
  /// sudah hilang — jadi server tidak pernah tahu, dan poll berikutnya
  /// menyisipkannya kembali karena baris itu jadi terlihat "belum pernah
  /// dilihat" oleh perangkat ini.
  Future<Result<void>> delete(String uuid) => runCatching(
    'Gagal menghapus transaksi',
    () async {
      final db = await getDatabase();
      await db.transaction((txn) async {
        await txn.delete(
          'transaction_items',
          where: 'transaction_uuid = ?',
          whereArgs: [uuid],
        );
        await txn.delete('transactions', where: 'uuid = ?', whereArgs: [uuid]);
        await txn.insert('pending_deletes', {
          'uuid': uuid,
          'deleted_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });
    },
  );

  /// Penghapusan yang belum diakui server.
  Future<Result<List<String>>> pendingDeletes({int limit = 200}) =>
      runCatching('Gagal memuat penghapusan tertunda', () async {
        final db = await getDatabase();
        final rows = await db.query(
          'pending_deletes',
          columns: ['uuid'],
          orderBy: 'deleted_at ASC',
          limit: limit,
        );
        return rows.map((r) => r['uuid'] as String).toList();
      });

  Future<Result<void>> clearPendingDeletes(List<String> uuids) =>
      runCatching('Gagal membersihkan penghapusan tertunda', () async {
        if (uuids.isEmpty) return;
        final db = await getDatabase();
        for (var i = 0; i < uuids.length; i += _hydrateChunk) {
          final chunk = uuids.skip(i).take(_hydrateChunk).toList();
          await db.delete(
            'pending_deletes',
            where: 'uuid IN (${List.filled(chunk.length, '?').join(',')})',
            whereArgs: chunk,
          );
        }
      });

  /// Marks a ticket redeemed. Guarded by a conditional UPDATE so two verifiers
  /// scanning the same ticket at once can't both succeed.
  Future<Result<RedeemOutcome>> redeem(String uuid) =>
      runCatching('Gagal memverifikasi tiket', () async {
        final db = await getDatabase();
        final existing = await _findByUuid(db, uuid);
        if (existing == null) return const TicketNotFound();

        final redeemedAt = DateTime.now();
        final updated = await db.update(
          'transactions',
          {
            'status': TransactionStatus.completed.dbValue,
            'redeemed_at': redeemedAt.toIso8601String(),
          },
          where: 'uuid = ? AND status = ?',
          whereArgs: [uuid, TransactionStatus.paid.dbValue],
        );

        if (updated == 0) return TicketAlreadyUsed(existing);

        return RedeemedOk(
          existing.copyWith(
            status: TransactionStatus.completed,
            redeemedAt: redeemedAt,
          ),
        );
      });

  /// Transactions not yet accepted by luminarabali.com, oldest first.
  ///
  /// [limit] matches the server's per-request cap, so a device that has been
  /// offline for weeks drains its backlog in batches instead of one request
  /// the server rejects wholesale.
  Future<Result<List<Transaction>>> unsynced({int limit = 200}) =>
      runCatching('Gagal memuat data yang belum tersinkron', () async {
        final db = await getDatabase();
        final rows = await db.query(
          'transactions',
          where: 'synced_at IS NULL',
          orderBy: 'created_at ASC',
          limit: limit,
        );
        return _hydrate(db, rows);
      });

  /// Raises the day's counter so the next sale can't reuse a number.
  ///
  /// Dipanggil saat perangkat ini mengambil peran kasir: perangkat sebelumnya
  /// mungkin sudah mencetak nomor yang lebih tinggi, dan tiket itu ada di
  /// tangan pelanggan. Tidak pernah menurunkan — hanya menaikkan.
  Future<Result<void>> raiseQueueCounter(String date, int lastNumber) =>
      runCatching('Gagal menyelaraskan nomor antrian', () async {
        if (lastNumber <= 0) return;
        final db = await getDatabase();
        await db.rawInsert(
          'INSERT INTO daily_queue_counter(date, last_number) VALUES(?, ?) '
          'ON CONFLICT(date) DO UPDATE SET '
          'last_number = MAX(last_number, excluded.last_number)',
          [date, lastNumber],
        );
      });

  Future<Result<int>> count() => runCatching(
    'Gagal menghitung transaksi',
    () async {
      final db = await getDatabase();
      final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM transactions');
      return rows.first['c'] as int? ?? 0;
    },
  );

  /// How many rows are still waiting to reach the server. Cheap enough to call
  /// from a settings screen; [unsynced] would hydrate every item for nothing.
  Future<Result<int>> unsyncedCount() =>
      runCatching('Gagal menghitung data yang belum tersinkron', () async {
        final db = await getDatabase();
        final rows = await db.rawQuery(
          'SELECT COUNT(*) AS c FROM transactions WHERE synced_at IS NULL',
        );
        return rows.first['c'] as int? ?? 0;
      });

  Future<Result<void>> markSynced(List<String> uuids, DateTime at) =>
      runCatching('Gagal menandai data tersinkron', () async {
        if (uuids.isEmpty) return;
        final db = await getDatabase();
        for (var i = 0; i < uuids.length; i += _hydrateChunk) {
          final chunk = uuids.skip(i).take(_hydrateChunk).toList();
          await db.update(
            'transactions',
            {'synced_at': at.toIso8601String()},
            where: 'uuid IN (${List.filled(chunk.length, '?').join(',')})',
            whereArgs: chunk,
          );
        }
      });

  /// Applies rows the server sent down, in one SQL transaction.
  ///
  /// Two rules, both falling straight out of "the cashier creates, the server
  /// redeems":
  ///
  ///   * a row carrying `deleted_at` is a **tombstone** — another till deleted
  ///     it, so delete it here too and never mind the other two rules;
  ///   * a row we've never seen belongs to **another till** — insert it, items
  ///     and all, already marked synced so [push] doesn't bounce it back;
  ///   * a row we already have is ours, so only the redemption may come down,
  ///     and only while we still think it's `PAID` — if it was redeemed here,
  ///     our `redeemed_at` is the one printed on the receipt.
  ///
  /// Idempotent on purpose: the server's cursor has one-second resolution and
  /// deliberately re-sends the boundary row rather than risk dropping it.
  ///
  /// Returns how many rows actually changed, so a caller can skip refreshing
  /// the UI when the poll brought nothing new.
  Future<Result<int>> applyRemote(
    List<Map<String, Object?>> headers,
    List<Map<String, Object?>> items,
  ) => runCatching('Gagal menerapkan data dari server', () async {
    if (headers.isEmpty) return 0;
    final db = await getDatabase();

    final itemsByUuid = <String, List<Map<String, Object?>>>{};
    for (final item in items) {
      final uuid = item['transaction_uuid'];
      if (uuid is String) itemsByUuid.putIfAbsent(uuid, () => []).add(item);
    }

    // Penghapusan yang belum sempat terkirim. Kalau push gagal tapi pull
    // berhasil, tanpa penjagaan ini baris yang baru saja dihapus kasir akan
    // muncul lagi di layarnya sendiri.
    final unsentDeletes = {
      for (final row in await db.query('pending_deletes', columns: ['uuid']))
        row['uuid'] as String,
    };

    var changed = 0;
    final touchedDates = <String>{};

    await db.transaction((txn) async {
      for (final row in headers) {
        final uuid = row['uuid'];
        if (uuid is! String) continue;
        if (unsentDeletes.contains(uuid)) continue;

        // Nisan menang atas segalanya: kasir lain sudah menghapusnya.
        if (row['deleted_at'] != null) {
          await txn.delete(
            'transaction_items',
            where: 'transaction_uuid = ?',
            whereArgs: [uuid],
          );
          changed += await txn.delete(
            'transactions',
            where: 'uuid = ?',
            whereArgs: [uuid],
          );
          continue;
        }

        final existing = await txn.query(
          'transactions',
          columns: ['uuid'],
          where: 'uuid = ?',
          whereArgs: [uuid],
          limit: 1,
        );

        if (existing.isEmpty) {
          // Kolom disebut satu per satu, bukan disebar dari respons: ini batas
          // kepercayaan. Kunci tak terduga dari server akan menggagalkan
          // seluruh insert kalau dibiarkan lewat.
          await txn.insert('transactions', {
            'uuid': uuid,
            'customer_name': row['customer_name'],
            'total_price': row['total_price'] ?? 0,
            'bayar_amount': row['bayar_amount'],
            'kembalian': row['kembalian'],
            'payment_method': row['payment_method'] ?? 'TUNAI',
            'status': row['status'] ?? TransactionStatus.paid.dbValue,
            'created_at': row['created_at'],
            'redeemed_at': row['redeemed_at'],
            'midtrans_order_id': row['midtrans_order_id'],
            'queue_number': row['queue_number'],
            'queue_date': row['queue_date'],
            'synced_at': DateTime.now().toIso8601String(),
          });

          for (final item in itemsByUuid[uuid] ?? const []) {
            await txn.insert('transaction_items', {
              'transaction_uuid': uuid,
              'product_name': item['product_name'],
              'product_price': item['product_price'] ?? 0,
              'quantity': item['quantity'] ?? 0,
            });
          }

          final date = row['queue_date'];
          if (date is String) touchedDates.add(date);
          changed++;
          continue;
        }

        if (row['status'] != TransactionStatus.completed.dbValue) continue;

        changed += await txn.update(
          'transactions',
          {
            'status': TransactionStatus.completed.dbValue,
            'redeemed_at':
                row['redeemed_at'] ?? DateTime.now().toIso8601String(),
          },
          where: 'uuid = ? AND status = ?',
          whereArgs: [uuid, TransactionStatus.paid.dbValue],
        );
      }

      // Tanpa ini kasir ini akan mengeluarkan nomor antrian yang sudah dipakai
      // kasir lain hari itu. Bukan pencegahan penuh — dua kasir yang menjual di
      // detik yang sama masih bisa bentrok sampai poll berikutnya — tapi
      // sesudahnya nomornya kembali menyusul.
      for (final date in touchedDates) {
        final rows = await txn.rawQuery(
          'SELECT MAX(queue_number) AS n FROM transactions WHERE queue_date = ?',
          [date],
        );
        final highest = rows.first['n'] as int?;
        if (highest == null) continue;

        await txn.rawInsert(
          'INSERT INTO daily_queue_counter(date, last_number) VALUES(?, ?) '
          'ON CONFLICT(date) DO UPDATE SET '
          'last_number = MAX(last_number, excluded.last_number)',
          [date, highest],
        );
      }
    });

    return changed;
  });

  Future<Result<Transaction?>> findByUuid(String uuid) =>
      runCatching('Gagal memuat transaksi', () async {
        final db = await getDatabase();
        return _findByUuid(db, uuid);
      });

  static Future<Transaction?> _findByUuid(Database db, String uuid) async {
    final rows = await db.query(
      'transactions',
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (await _hydrate(db, rows)).first;
  }

  /// Attaches items to headers using one extra query for the whole batch
  /// instead of one per transaction.
  static Future<List<Transaction>> _hydrate(
    Database db,
    List<Map<String, Object?>> headers,
  ) async {
    if (headers.isEmpty) return const [];

    final uuids = headers.map((h) => h['uuid'] as String).toList();
    final itemsByUuid = <String, List<TransactionItem>>{};

    // Chunked: SQLite caps bound variables (999 on older builds), so a single
    // IN clause over the whole history throws once there are enough rows.
    for (var i = 0; i < uuids.length; i += _hydrateChunk) {
      final chunk = uuids.skip(i).take(_hydrateChunk).toList();
      final itemRows = await db.query(
        'transaction_items',
        where:
            'transaction_uuid IN (${List.filled(chunk.length, '?').join(',')})',
        whereArgs: chunk,
        orderBy: 'id ASC',
      );
      for (final row in itemRows) {
        itemsByUuid
            .putIfAbsent(row['transaction_uuid'] as String, () => [])
            .add(TransactionItem.fromMap(row));
      }
    }

    return headers
        .map((h) => Transaction.fromMap(h, itemsByUuid[h['uuid']] ?? const []))
        .toList();
  }
}
