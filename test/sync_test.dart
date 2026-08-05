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

  /// Hari ini, karena `create` menomori antrian menurut jam perangkat — kasir
  /// lain di tes ini harus berjualan di hari yang sama supaya counter-nya beradu.
  final today = DateTime.now().toIso8601String().substring(0, 10);

  /// Satu baris seperti yang dikirim `/api/pos/restore`.
  Map<String, Object?> remote(
    String uuid, {
    String status = 'PAID',
    String? redeemedAt,
    int? queueNumber,
  }) => {
    'uuid': uuid,
    'customer_name': 'Sari',
    'total_price': 75000,
    'bayar_amount': null,
    'kembalian': null,
    'payment_method': 'QRIS',
    'status': status,
    'created_at': '2026-08-04T10:00:00.000',
    'redeemed_at': redeemedAt,
    'midtrans_order_id': null,
    'queue_number': queueNumber,
    'queue_date': today,
  };

  test('Penukaran dari perangkat lain diterapkan ke SQLite lokal', () async {
    expectOk(await repo.create(sale('a')));

    final changed = expectOk(
      await repo.applyRemote([
        remote(
          'a',
          status: 'COMPLETED',
          redeemedAt: DateTime(2026, 8, 4, 12).toIso8601String(),
        ),
      ], const []),
    );

    expect(changed, 1);
    final trx = expectOk(await repo.findByUuid('a'))!;
    expect(trx.status, TransactionStatus.completed);
    expect(trx.redeemedAt, DateTime(2026, 8, 4, 12));

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
        await repo.applyRemote([
          remote('a', status: 'COMPLETED', redeemedAt: '2020-01-01T00:00:00.0'),
        ], const []),
      );

      expect(changed, 0);
      expect(expectOk(await repo.findByUuid('a'))!.redeemedAt, localRedeemedAt);
    },
  );

  test('Transaksi kasir lain masuk lengkap dengan itemnya', () async {
    // Kasir ini sudah punya #1 hari itu; kasir lain menjual #2.
    expectOk(await repo.create(sale('a')));

    final changed = expectOk(
      await repo.applyRemote(
        [remote('b', queueNumber: 2)],
        const [
          {
            'transaction_uuid': 'b',
            'product_name': 'Wide Angle Photo',
            'product_price': 75000,
            'quantity': 1,
          },
        ],
      ),
    );

    expect(changed, 1);
    final trx = expectOk(await repo.findByUuid('b'))!;
    expect(trx.customerName, 'Sari');
    expect(trx.items.single.productName, 'Wide Angle Photo');
    // Metode pembayaran bebas-teks harus lolos apa adanya, bukan jadi TUNAI.
    expect(trx.paymentMethod.dbValue, 'QRIS');

    // Baris ini datang DARI server: mendorongnya balik cuma memutar data.
    expect(expectOk(await repo.unsynced()).map((t) => t.uuid), ['a']);

    // Counter antrian ikut naik, jadi penjualan berikutnya di perangkat ini
    // dapat #3 dan bukan mengulang nomor kasir lain.
    expect(expectOk(await repo.create(sale('c'))), 3);
  });

  test('Baris yang sama dikirim ulang tidak menggandakan apa pun', () async {
    final page = [remote('b', queueNumber: 2)];
    const items = [
      {
        'transaction_uuid': 'b',
        'product_name': 'Wide Angle Photo',
        'product_price': 75000,
        'quantity': 1,
      },
    ];

    // Kursor server berpresisi detik, jadi baris pembatas memang sengaja
    // dikirim lagi setiap poll. Itu harus tidak berakibat apa-apa.
    expect(expectOk(await repo.applyRemote(page, items)), 1);
    expect(expectOk(await repo.applyRemote(page, items)), 0);

    expect(expectOk(await repo.findByUuid('b'))!.items, hasLength(1));
  });
}
