import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

bool _isDbInitialized = false;

Future<Database> getDatabase() async {
  if (Platform.isWindows || Platform.isLinux) {
    if (!_isDbInitialized) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _isDbInitialized = true;
    }
  }
  
  Database database = await openDatabase(
    join(await getDatabasesPath(), 'photobooth.db'),
    version: 1,
    onCreate: (db, version) async {
      // Tabel: products (Simplified for Photobooth)
      await db.execute('''
        CREATE TABLE products (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          price INTEGER NOT NULL
        )
      ''');

      // Tabel: transactions (Simplified for Photobooth)
      await db.execute('''
        CREATE TABLE transactions (
          uuid TEXT PRIMARY KEY,
          customer_name TEXT,
          product_name TEXT NOT NULL,
          product_price INTEGER NOT NULL,
          status TEXT NOT NULL DEFAULT 'PAID',
          created_at TEXT NOT NULL,
          redeemed_at TEXT
        )
      ''');

      // Seed some default data if empty
      await db.insert('products', {'name': 'Self Photo 15 Menit', 'price': 50000});
      await db.insert('products', {'name': 'Wide Angle Photo', 'price': 75000});
    },
  );

  return database;
}

// Optimized for Photobooth Management System
Future<Map<String, dynamic>> getStatistics() async {
  final db = await getDatabase();

  final now = DateTime.now();
  final todayStr = DateTime(now.year, now.month, now.day).toIso8601String().substring(0, 10);

  // Today's Income
  final todayIncomeResult = await db.rawQuery(
    "SELECT COALESCE(SUM(product_price), 0) as total FROM transactions WHERE created_at LIKE '$todayStr%'",
  );
  final todayIncome = Sqflite.firstIntValue(todayIncomeResult) ?? 0;

  // Today's Transactions
  final todayTransactionResult = await db.rawQuery(
    "SELECT COUNT(*) as total FROM transactions WHERE created_at LIKE '$todayStr%'",
  );
  final todayTransactions = Sqflite.firstIntValue(todayTransactionResult) ?? 0;

  // Total Queue (PAID but not COMPLETED)
  final queueResult = await db.rawQuery(
    "SELECT COUNT(*) as total FROM transactions WHERE status = 'PAID'",
  );
  final queueCount = Sqflite.firstIntValue(queueResult) ?? 0;

  // Total Products
  final totalProdukResult = await db.rawQuery('SELECT COUNT(*) as total FROM products');
  final totalProduk = Sqflite.firstIntValue(totalProdukResult) ?? 0;

  return {
    'today_income': todayIncome,
    'today_transactions': todayTransactions,
    'queue_count': queueCount,
    'total_produk': totalProduk,
  };
}

// Growth placeholder for new schema compatibility
Future<Map<String, dynamic>> getSalesGrowth() async {
  return {
    'this_month': 0,
    'last_month': 0,
    'growth_percentage': 0.0,
  };
}

// Low stock placeholder (Photobooth doesn't really have stock, it's time-based/service-based)
Future<List<Map<String, dynamic>>> getLowStockProducts() async {
  return [];
}
