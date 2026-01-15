import 'package:luminara_photobooth/core/data/db.dart';
import 'dart:math';
import 'package:sqflite/sqflite.dart';

class Transaksi {
  final String uuid;
  final String? customerName;
  final String productName;
  final int productPrice;
  final String status;
  final DateTime createdAt;
  final DateTime? redeemedAt;

  Transaksi({
    required this.uuid,
    this.customerName,
    required this.productName,
    required this.productPrice,
    this.status = 'PAID',
    required this.createdAt,
    this.redeemedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'customer_name': customerName,
      'product_name': productName,
      'product_price': productPrice,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'redeemed_at': redeemedAt?.toIso8601String(),
    };
  }

  factory Transaksi.fromMap(Map<String, dynamic> map) {
    return Transaksi(
      uuid: map['uuid'],
      customerName: map['customer_name'],
      productName: map['product_name'],
      productPrice: map['product_price'],
      status: map['status'],
      createdAt: DateTime.parse(map['created_at']),
      redeemedAt: map['redeemed_at'] != null ? DateTime.parse(map['redeemed_at']) : null,
    );
  }

  static Future<void> createTransaksi(Transaksi transaksi) async {
    final db = await getDatabase();
    await db.insert(
      'transactions',
      transaksi.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Transaksi>> getAllTransaksi() async {
    final db = await getDatabase();
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) {
      return Transaksi.fromMap(maps[i]);
    });
  }

  static Future<List<Transaksi>> getTransactionsByDateRange(
      DateTime start, DateTime end) async {
    final db = await getDatabase();
    // Normalisasi start ke awal hari (00:00:00) dan end ke akhir hari (23:59:59)
    final startOfDay = DateTime(start.year, start.month, start.day, 0, 0, 0);
    final endOfDay = DateTime(end.year, end.month, end.day, 23, 59, 59);

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'created_at BETWEEN ? AND ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) {
      return Transaksi.fromMap(maps[i]);
    });
  }

  static Future<List<DateTime>> getAvailableTransactionMonths() async {
    final db = await getDatabase();
    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT DISTINCT strftime("%Y-%m", created_at) as month_str FROM transactions ORDER BY created_at DESC',
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