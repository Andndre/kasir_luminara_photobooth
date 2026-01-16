import 'package:luminara_photobooth/core/data/db.dart';
import 'dart:math';
import 'package:sqflite/sqflite.dart';

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
  final String? midtransOrderId; // NEW FIELD

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
    };
  }

  factory Transaksi.fromMap(Map<String, dynamic> map, List<TransaksiItem> items) {
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
      redeemedAt:
          map['redeemed_at'] != null ? DateTime.parse(map['redeemed_at']) : null,
      midtransOrderId: map['midtrans_order_id'],
    );
  }

  static Future<void> createTransaksi(Transaksi transaksi) async {
    final db = await getDatabase();
    await db.transaction((txn) async {
      // 1. Insert Transaction header
      await txn.insert(
        'transactions',
        transaksi.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Insert Items
      for (var item in transaksi.items) {
        await txn.insert(
          'transaction_items',
          item.toMap(transaksi.uuid),
        );
      }
    });
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
      DateTime start, DateTime end) async {
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
      await txn.delete(
        'transactions',
        where: 'uuid = ?',
        whereArgs: [uuid],
      );
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
    return List.generate(8, (index) => chars[random.nextInt(chars.length)])
        .join();
  }
}