import 'package:kasir/core/data/db.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

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

  static String generateUuid() {
    return const Uuid().v4();
  }
}