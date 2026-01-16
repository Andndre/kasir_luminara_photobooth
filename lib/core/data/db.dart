import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// WAJIB: Import path_provider untuk akses folder yang aman di Desktop
import 'package:path_provider/path_provider.dart';

// Variable untuk memastikan FFI hanya di-init sekali
bool _isDbInitialized = false;

Future<Database> getDatabase() async {
  if (Platform.isWindows || Platform.isLinux) {
    if (!_isDbInitialized) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _isDbInitialized = true;
    }
  }

  String dbPath;

  if (Platform.isWindows || Platform.isLinux) {
    // DESKTOP: Gunakan folder Application Support agar memiliki izin TULIS (Write)
    // Linux: ~/.local/share/luminara_photobooth/photobooth.db
    // Windows: C:\Users\Nama\AppData\Roaming\luminara_photobooth\photobooth.db
    final directory = await getApplicationSupportDirectory();

    // Pastikan folder tersebut ada. Jika belum, buat dulu.
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    dbPath = join(directory.path, 'photobooth.db');
  } else {
    dbPath = join(await getDatabasesPath(), 'photobooth.db');
  }

  // ------------------------------------------------------------------
  // 3. Buka Database & Buat Tabel
  // ------------------------------------------------------------------
  Database database = await openDatabase(
    dbPath,
    version: 2,
    onCreate: (db, version) async {
      print("Creating new database tables...");

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
          redeemed_at TEXT,
          midtrans_order_id TEXT
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

      // Tabel: logs
      await db.execute('''
        CREATE TABLE logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          timestamp TEXT NOT NULL,
          message TEXT NOT NULL,
          is_error INTEGER NOT NULL DEFAULT 0
        )
      ''');

      // Seed default data (Data awal)
      await db.insert('products', {
        'name': 'Self Photo 15 Menit',
        'price': 50000,
      });
      await db.insert('products', {'name': 'Wide Angle Photo', 'price': 75000});

      print("✅ Database siap digunakan!");
    },
    onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        print("Upgrading database from version $oldVersion to $newVersion...");

        await db.execute('''
          CREATE TABLE IF NOT EXISTS logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            message TEXT NOT NULL,
            is_error INTEGER NOT NULL DEFAULT 0
          )
        ''');

        print("✅ Database upgraded to version $newVersion");
      }
    },
  );

  return database;
}

// Optimized for Photobooth Management System
Future<Map<String, dynamic>> getStatistics() async {
  final db = await getDatabase();

  final now = DateTime.now();
  final todayStr = DateTime(
    now.year,
    now.month,
    now.day,
  ).toIso8601String().substring(0, 10);

  // Today's Income
  final todayIncomeResult = await db.rawQuery(
    "SELECT COALESCE(SUM(total_price), 0) as total FROM transactions WHERE created_at LIKE '$todayStr%'",
  );
  final todayIncome = Sqflite.firstIntValue(todayIncomeResult) ?? 0;

  // Today's Transactions
  final todayTransactionResult = await db.rawQuery(
    "SELECT COUNT(*) as total FROM transactions WHERE created_at LIKE '$todayStr%'",
  );
  final todayTransactions = Sqflite.firstIntValue(todayTransactionResult) ?? 0;

  // Total Queue (PAID but not COMPLETED/Redeemed)
  final queueResult = await db.rawQuery(
    "SELECT COUNT(*) as total FROM transactions WHERE status = 'PAID'",
  );
  final queueCount = Sqflite.firstIntValue(queueResult) ?? 0;

  // Total Products
  final totalProdukResult = await db.rawQuery(
    'SELECT COUNT(*) as total FROM products',
  );
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
  return {'this_month': 0, 'last_month': 0, 'growth_percentage': 0.0};
}
