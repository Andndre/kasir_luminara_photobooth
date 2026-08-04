import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Current schema version. Bump this *and* add an `oldVersion < n` branch in
/// [_onUpgrade] — never edit [_onCreate] alone, or upgraded installs will be
/// missing whatever you added.
const _schemaVersion = 4;

/// FFI must be initialised exactly once per process, before any DB call.
bool _ffiInitialized = false;

/// Cached handle. `openDatabase` was previously called on every access, which
/// re-resolved the path and re-opened the file for each query.
Database? _database;
Future<Database>? _opening;

bool get _isDesktop => Platform.isWindows || Platform.isLinux;

/// Opens (once) and returns the app database. Safe to call from anywhere.
Future<Database> getDatabase() async {
  final existing = _database;
  if (existing != null && existing.isOpen) return existing;
  // Runs synchronously up to here, so concurrent callers during startup all
  // await the same open instead of racing to open the file several times.
  return _opening ??= _openAndCache();
}

Future<Database> _openAndCache() async {
  try {
    return _database = await _open();
  } finally {
    _opening = null;
  }
}

Future<Database> _open() async {
  if (_isDesktop && !_ffiInitialized) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _ffiInitialized = true;
  }

  return openDatabase(
    await _resolveDatabasePath(),
    version: _schemaVersion,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
  );
}

/// Overrides where the database file lives. Tests set this to
/// `inMemoryDatabasePath`; without it they hit `path_provider`, which has no
/// implementation under `flutter test`.
@visibleForTesting
String? debugDatabasePath;

/// Closes and forgets the cached handle, so the next [getDatabase] opens a
/// fresh one. Tests use this to isolate cases from each other.
@visibleForTesting
Future<void> resetDatabase() async {
  await _database?.close();
  _database = null;
  _opening = null;
}

Future<String> _resolveDatabasePath() async {
  final override = debugDatabasePath;
  if (override != null) return override;

  if (!_isDesktop) {
    return join(await getDatabasesPath(), 'photobooth.db');
  }

  // Application Support is the writable per-user location on desktop:
  //   Linux:   ~/.local/share/luminara_photobooth/
  //   Windows: %APPDATA%\luminara_photobooth\
  final directory = await getApplicationSupportDirectory();
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }
  return join(directory.path, 'photobooth.db');
}

// ---------------------------------------------------------------------------
// Schema. Table and column names here are contractual: shipped installs hold
// real data under these exact names. Renaming any of them needs a migration.
// ---------------------------------------------------------------------------

Future<void> _onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE products (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      price INTEGER NOT NULL
    )
  ''');

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
      midtrans_order_id TEXT,
      queue_number INTEGER,
      queue_date TEXT,
      synced_at TEXT
    )
  ''');

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

  await db.execute(_createLogsTable);
  await db.execute(_createQueueCounterTable);

  await db.insert('products', {'name': 'Self Photo 15 Menit', 'price': 50000});
  await db.insert('products', {'name': 'Wide Angle Photo', 'price': 75000});

  debugPrint('Database created at schema v$version');
}

Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  debugPrint('Upgrading database v$oldVersion -> v$newVersion');

  if (oldVersion < 2) {
    await db.execute(_createLogsTable);
  }

  if (oldVersion < 3) {
    await db.execute(
      'ALTER TABLE transactions ADD COLUMN queue_number INTEGER',
    );
    await db.execute('ALTER TABLE transactions ADD COLUMN queue_date TEXT');
    await db.execute(_createQueueCounterTable);
  }

  if (oldVersion < 4) {
    // NULL berarti "belum terkirim ke luminarabali.com". Baris lama sengaja
    // dibiarkan NULL supaya riwayat yang sudah ada ikut terdorong ke server
    // saat pertama kali login.
    await db.execute('ALTER TABLE transactions ADD COLUMN synced_at TEXT');
  }
}

// Shared between _onCreate and _onUpgrade so the two can't drift apart.
const _createLogsTable = '''
  CREATE TABLE IF NOT EXISTS logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    message TEXT NOT NULL,
    is_error INTEGER NOT NULL DEFAULT 0
  )
''';

const _createQueueCounterTable = '''
  CREATE TABLE IF NOT EXISTS daily_queue_counter (
    date TEXT PRIMARY KEY,
    last_number INTEGER NOT NULL DEFAULT 0
  )
''';
