import 'package:luminara_photobooth/core/data/db.dart';
import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';

class TransaksiItem {
  final int? id;
  final String productName;
  final int productPrice;
  final int quantity;

  TransaksiItem({
    this.id,
    required this.productName,
    required this.productPrice,
    required this.quantity,
  });

  Map<String, dynamic> toMap(String transactionUuid) {
    return {
      'transaction_uuid': transactionUuid,
      'product_name': productName,
      'product_price': productPrice,
      'quantity': quantity,
    };
  }

  factory TransaksiItem.fromMap(Map<String, dynamic> map) {
    return TransaksiItem(
      id: map['id'],
      productName: map['product_name'],
      productPrice: map['product_price'],
      quantity: map['quantity'],
    );
  }
}

class Transaksi {
  final String uuid;
  final String? customerName;
  final List<TransaksiItem> items;
  final int totalPrice;
  final int? bayarAmount;
  final int? kembalian;
  final String paymentMethod;
  final String status;
  final DateTime createdAt;
  final DateTime? redeemedAt;
  final String? midtransOrderId;
  final int? queueNumber;
  final String? queueDate;

  Transaksi({
    required this.uuid,
    this.customerName,
    required this.items,
    required this.totalPrice,
    this.bayarAmount,
    this.kembalian,
    this.paymentMethod = 'TUNAI',
    this.status = 'PAID',
    required this.createdAt,
    this.redeemedAt,
    this.midtransOrderId,
    this.queueNumber,
    this.queueDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'customer_name': customerName,
      'total_price': totalPrice,
      'bayar_amount': bayarAmount,
      'kembalian': kembalian,
      'payment_method': paymentMethod,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'redeemed_at': redeemedAt?.toIso8601String(),
      'midtrans_order_id': midtransOrderId,
      'queue_number': queueNumber,
      'queue_date': queueDate,
    };
  }

  factory Transaksi.fromMap(
    Map<String, dynamic> map,
    List<TransaksiItem> items,
  ) {
    return Transaksi(
      uuid: map['uuid'],
      customerName: map['customer_name'],
      items: items,
      totalPrice: map['total_price'] ?? 0,
      bayarAmount: map['bayar_amount'],
      kembalian: map['kembalian'],
      paymentMethod: map['payment_method'] ?? 'TUNAI',
      status: map['status'],
      createdAt: DateTime.parse(map['created_at']),
      redeemedAt: map['redeemed_at'] != null
          ? DateTime.parse(map['redeemed_at'])
          : null,
      midtransOrderId: map['midtrans_order_id'],
      queueNumber: map['queue_number'],
      queueDate: map['queue_date'],
    );
  }

  static Future<int> createTransaksi(Transaksi transaksi) async {
    final db = await getDatabase();
    late int queueNumber;
    await db.transaction((txn) async {
      // Generate queue number within transaction
      queueNumber = await _generateQueueNumber(txn);
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Prepare map with queue fields
      final map = transaksi.toMap();
      map['queue_number'] = queueNumber;
      map['queue_date'] = today;

      // 1. Insert Transaction header
      await txn.insert(
        'transactions',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Insert Items
      for (var item in transaksi.items) {
        await txn.insert('transaction_items', item.toMap(transaksi.uuid));
      }
    });
    return queueNumber;
  }

  static Future<int> _generateQueueNumber(DatabaseExecutor db) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final result = await db.query(
      'daily_queue_counter',
      where: 'date = ?',
      whereArgs: [today],
    );

    int nextNumber;
    if (result.isEmpty) {
      nextNumber = 1;
      await db.insert('daily_queue_counter', {
        'date': today,
        'last_number': 1,
      });
    } else {
      nextNumber = (result.first['last_number'] as int) + 1;
      await db.update(
        'daily_queue_counter',
        {'last_number': nextNumber},
        where: 'date = ?',
        whereArgs: [today],
      );
    }
    return nextNumber;
  }

  static Future<List<Transaksi>> getAllTransaksi() async {
    final db = await getDatabase();
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      orderBy: 'created_at DESC',
    );

    List<Transaksi> list = [];
    for (var map in maps) {
      final itemsMap = await db.query(
        'transaction_items',
        where: 'transaction_uuid = ?',
        whereArgs: [map['uuid']],
      );
      final items = itemsMap.map((i) => TransaksiItem.fromMap(i)).toList();
      list.add(Transaksi.fromMap(map, items));
    }
    return list;
  }

  static Future<List<Transaksi>> getTransactionsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await getDatabase();
    final startOfDay = DateTime(start.year, start.month, start.day, 0, 0, 0);
    final endOfDay = DateTime(end.year, end.month, end.day, 23, 59, 59);

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'created_at BETWEEN ? AND ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'created_at DESC',
    );

    List<Transaksi> list = [];
    for (var map in maps) {
      final itemsMap = await db.query(
        'transaction_items',
        where: 'transaction_uuid = ?',
        whereArgs: [map['uuid']],
      );
      final items = itemsMap.map((i) => TransaksiItem.fromMap(i)).toList();
      list.add(Transaksi.fromMap(map, items));
    }
    return list;
  }

  static Future<void> deleteTransaksi(String uuid) async {
    final db = await getDatabase();
    await db.transaction((txn) async {
      await txn.delete(
        'transaction_items',
        where: 'transaction_uuid = ?',
        whereArgs: [uuid],
      );
      await txn.delete('transactions', where: 'uuid = ?', whereArgs: [uuid]);
    });
  }

  static Future<List<DateTime>> getAvailableTransactionMonths() async {
    final db = await getDatabase();
    final List<Map<String, dynamic>> result = await db.rawQuery(
      "SELECT DISTINCT strftime('%Y-%m', created_at) as month_str FROM transactions ORDER BY created_at DESC",
    );

    return result
        .map((row) => DateTime.parse('${row['month_str']}-01'))
        .toList();
  }

  static String generateUuid() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(
      8,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }
}
