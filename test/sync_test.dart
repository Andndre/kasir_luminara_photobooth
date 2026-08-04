import 'package:flutter_test/flutter_test.dart';
import 'package:luminara_photobooth/core/data/db.dart';
import 'package:luminara_photobooth/core/data/repositories/transaction_repository.dart';
import 'package:luminara_photobooth/core/data/result.dart';
import 'package:luminara_photobooth/core/domain/domain.dart';
// Hides sqflite's own `Transaction` so the domain one wins here.
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

T expectOk<T>(Result<T> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final message) => fail(message),
};

/// Menahan sisi klien dari sync ke luminarabali.com.
///
/// Aturan yang dijaga: kasir yang membuat transaksi, server yang menukarkan
/// tiket. Kalau salah satu tes ini gugur, transaksi bisa hilang dari laporan
/// atau tiket yang sudah ditukar tampak masih bisa dipakai.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const repo = TransactionRepository();

  setUp(() async {
    debugDatabasePath = inMemoryDatabasePath;
    await resetDatabase();
  });

  tearDown(() async {
    await resetDatabase();
    debugDatabasePath = null;
  });

  Transaction sale(String uuid) => Transaction(
    uuid: uuid,
    customerName: 'Budi',
    items: const [
      TransactionItem(
        productName: 'Self Photo 15 Menit',
        productPrice: 50000,
        quantity: 1,
      ),
    ],
    totalPrice: 50000,
    createdAt: DateTime(2026, 8, 4, 10),
  );

  test('Transaksi baru dianggap belum tersinkron', () async {
    expectOk(await repo.create(sale('a')));

    final pending = expectOk(await repo.unsynced());
    expect(pending.map((t) => t.uuid), ['a']);
  });

  test('Yang sudah ditandai tidak terkirim dua kali', () async {
    expectOk(await repo.create(sale('a')));
    expectOk(await repo.create(sale('b')));

    expectOk(await repo.markSynced(['a'], DateTime(2026, 8, 4, 11)));

    expect(expectOk(await repo.unsynced()).map((t) => t.uuid), ['b']);
  });

  test('Penukaran dari perangkat lain diterapkan ke SQLite lokal', () async {
    expectOk(await repo.create(sale('a')));

    final redeemedAt = DateTime(2026, 8, 4, 12);
    final changed = expectOk(await repo.applyRedemptions({'a': redeemedAt}));

    expect(changed, 1);
    final trx = expectOk(await repo.findByUuid('a'))!;
    expect(trx.status, TransactionStatus.completed);
    expect(trx.redeemedAt, redeemedAt);

    // Antrian ikut kosong, jadi tiket itu tidak dipanggil lagi di booth.
    expect(expectOk(await repo.pendingQueue()), isEmpty);
  });

  test(
    'Penukaran dari server tidak menimpa yang sudah dicetak lokal',
    () async {
      expectOk(await repo.create(sale('a')));
      expectOk(await repo.redeem('a'));

      final localRedeemedAt = expectOk(await repo.findByUuid('a'))!.redeemedAt;

      // Server mengabarkan penukaran yang sama dengan jam berbeda. Yang dicetak
      // di struk adalah jam lokal, jadi jam itu yang harus bertahan.
      final changed = expectOk(
        await repo.applyRedemptions({'a': DateTime(2020, 1, 1)}),
      );

      expect(changed, 0);
      expect(expectOk(await repo.findByUuid('a'))!.redeemedAt, localRedeemedAt);
    },
  );

  test('Kabar penukaran untuk uuid asing diabaikan diam-diam', () async {
    expect(expectOk(await repo.applyRedemptions({'tidak-ada': null})), 0);
  });
}
