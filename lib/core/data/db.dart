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
    version: 4,
    onCreate: (db, version) async {
      // Tabel: products
      await db.execute('''
        CREATE TABLE products (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          price INTEGER NOT NULL
        )
      ''');

      // Tabel: transactions
      await db.execute('''
        CREATE TABLE transactions (
          uuid TEXT PRIMARY KEY,
          customer_name TEXT,
          total_price INTEGER NOT NULL,
          bayar_amount INTEGER,
          kembalian INTEGER,
          payment_method TEXT NOT NULL DEFAULT 'TUNAI',
          status TEXT NOT NULL DEFAULT 'PAID',
          created_at TEXT NOT NULL,
          redeemed_at TEXT
        )
      ''');

      // Tabel: transaction_items
      await db.execute('''
        CREATE TABLE transaction_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          transaction_uuid TEXT NOT NULL,
          product_name TEXT NOT NULL,
          product_price INTEGER NOT NULL,
          quantity INTEGER NOT NULL,
          FOREIGN KEY (transaction_uuid) REFERENCES transactions (uuid) ON DELETE CASCADE
        )
      ''');

      // Seed default data
      await db
          .insert('products', {'name': 'Self Photo 15 Menit', 'price': 50000});
      await db.insert('products', {'name': 'Wide Angle Photo', 'price': 75000});
    },
    onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 3) {
        // Migrasi bersih untuk menghapus kolom lama yang mengganggu (product_name, product_price)
        
        // 1. Rename tabel lama
        await db.execute('ALTER TABLE transactions RENAME TO transactions_old');

        // 2. Buat tabel baru dengan skema benar
        await db.execute('''
          CREATE TABLE transactions (
            uuid TEXT PRIMARY KEY,
            customer_name TEXT,
            total_price INTEGER NOT NULL,
            payment_method TEXT NOT NULL DEFAULT 'TUNAI',
            status TEXT NOT NULL DEFAULT 'PAID',
            created_at TEXT NOT NULL,
            redeemed_at TEXT
          )
        ''');

        // 3. Pindahkan data dan hitung total_price (fallback ke product_price jika ada)
        try {
          await db.execute('''
            INSERT INTO transactions (uuid, customer_name, total_price, status, created_at, redeemed_at)
            SELECT uuid, customer_name, product_price, status, created_at, redeemed_at FROM transactions_old
          ''');
        } catch (_) {
          await db.execute('''
            INSERT INTO transactions (uuid, customer_name, total_price, payment_method, status, created_at, redeemed_at)
            SELECT uuid, customer_name, total_price, payment_method, status, created_at, redeemed_at FROM transactions_old
          ''');
        }

        // 4. Hapus tabel lama
        await db.execute('DROP TABLE transactions_old');

        // 5. Pastikan tabel items ada
        await db.execute('''
          CREATE TABLE IF NOT EXISTS transaction_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            transaction_uuid TEXT NOT NULL,
            product_name TEXT NOT NULL,
            product_price INTEGER NOT NULL,
            quantity INTEGER NOT NULL,
            FOREIGN KEY (transaction_uuid) REFERENCES transactions (uuid) ON DELETE CASCADE
          )
        ''');
      }

      if (oldVersion < 4) {
        // Tambahkan kolom bayar_amount dan kembalian
        try {
          await db.execute('ALTER TABLE transactions ADD COLUMN bayar_amount INTEGER');
          await db.execute('ALTER TABLE transactions ADD COLUMN kembalian INTEGER');
        } catch (_) {}
      }
    },
  );

  return database;
}

// Optimized for Photobooth Management System
Future<Map<String, dynamic>> getStatistics() async {
  final db = await getDatabase();

  final now = DateTime.now();
  final todayStr =
      DateTime(now.year, now.month, now.day).toIso8601String().substring(0, 10);

  // Today's Income (Menggunakan total_price baru)
  final todayIncomeResult = await db.rawQuery(
    "SELECT COALESCE(SUM(total_price), 0) as total FROM transactions WHERE created_at LIKE '$todayStr%'",
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
  final totalProdukResult =
      await db.rawQuery('SELECT COUNT(*) as total FROM products');
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
