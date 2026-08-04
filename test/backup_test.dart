import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:luminara_photobooth/core/data/db.dart';
import 'package:luminara_photobooth/core/data/repositories/product_repository.dart';
import 'package:luminara_photobooth/core/data/repositories/transaction_repository.dart';
import 'package:luminara_photobooth/core/data/result.dart';
import 'package:luminara_photobooth/core/domain/domain.dart';
import 'package:luminara_photobooth/features/settings/services/backup_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

T unwrap<T>(Result<T> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final message) => fail(message),
};

Transaction sampleTransaction(String uuid) => Transaction(
  uuid: uuid,
  customerName: 'Budi',
  items: const [
    TransactionItem(
      productName: 'Self Photo 15 Menit',
      productPrice: 50000,
      quantity: 2,
    ),
  ],
  totalPrice: 100000,
  amountPaid: 100000,
  paymentMethod: PaymentMethod.cash,
  createdAt: DateTime.parse('2026-08-01T10:00:00.000'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const products = ProductRepository();
  const transactions = TransactionRepository();

  setUp(() async {
    await resetDatabase();
    debugDatabasePath = inMemoryDatabasePath;
  });

  tearDown(resetDatabase);

  test('Backup lalu restore mengembalikan data yang sama', () async {
    unwrap(await products.create(const Product(name: 'Paket Uji', price: 12345)));
    unwrap(await transactions.create(sampleTransaction('TIKET-1')));

    final backup = await BackupService.buildBackupJson();

    // Data berubah setelah backup diambil.
    unwrap(await products.create(const Product(name: 'Paket Baru', price: 999)));
    unwrap(await transactions.create(sampleTransaction('TIKET-2')));

    await BackupService.applyBackupJson(backup);

    final restoredProducts = unwrap(await products.all());
    expect(restoredProducts.map((p) => p.name), contains('Paket Uji'));
    expect(restoredProducts.map((p) => p.name), isNot(contains('Paket Baru')));

    final restoredTx = unwrap(await transactions.all());
    expect(restoredTx.map((t) => t.uuid), ['TIKET-1']);

    final ticket = restoredTx.single;
    expect(ticket.customerName, 'Budi');
    expect(ticket.totalPrice, 100000);
    expect(ticket.paymentMethod, PaymentMethod.cash);
    expect(ticket.status, TransactionStatus.paid);
    expect(ticket.items.single.productName, 'Self Photo 15 Menit');
    expect(ticket.items.single.quantity, 2);
    expect(ticket.queueNumber, isNotNull);
  });

  test('Backup memuat semua tabel yang dijanjikan', () async {
    final decoded =
        json.decode(await BackupService.buildBackupJson())
            as Map<String, dynamic>;

    expect(decoded['version'], isNotNull);
    expect(decoded['created_at'], isNotNull);
    expect(
      (decoded['tables'] as Map).keys,
      containsAll([
        'products',
        'transactions',
        'transaction_items',
        'logs',
        'daily_queue_counter',
      ]),
    );
  });

  test('File rusak ditolak tanpa menghapus data yang ada', () async {
    unwrap(await products.create(const Product(name: 'Jangan Hilang', price: 1)));
    final before = unwrap(await products.all()).length;

    for (final bad in [
      'bukan json sama sekali',
      '{}', // tidak ada version/tables
      '{"version":"1.0"}', // tidak ada tables
      '{"version":"1.0","tables":{"products":"bukan list"}}',
      '[]', // json valid tapi bukan object
    ]) {
      await expectLater(
        BackupService.applyBackupJson(bad),
        throwsA(isA<FormatException>()),
        reason: 'seharusnya ditolak: $bad',
      );
    }

    // Data lama masih utuh.
    expect(unwrap(await products.all()).length, before);
    expect(
      unwrap(await products.all()).map((p) => p.name),
      contains('Jangan Hilang'),
    );
  });

  test('Backup kosong tetap bisa dipulihkan', () async {
    final empty = json.encode({
      'version': '1.0',
      'tables': {'products': [], 'transactions': []},
    });

    await BackupService.applyBackupJson(empty);

    expect(unwrap(await products.all()), isEmpty);
    expect(unwrap(await transactions.all()), isEmpty);
  });
}
