import 'package:flutter_test/flutter_test.dart';
import 'package:luminara_photobooth/core/data/db.dart';
import 'package:luminara_photobooth/core/data/repositories/product_repository.dart';
import 'package:luminara_photobooth/core/data/repositories/transaction_repository.dart';
import 'package:luminara_photobooth/core/data/result.dart';
import 'package:luminara_photobooth/core/domain/domain.dart';
import 'package:luminara_photobooth/core/preferences/printer_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Hides sqflite's own `Transaction` so the domain one wins here.
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
import 'package:uuid/uuid.dart';

/// Unwraps a [Result], failing the test with the error message instead of a
/// bare cast exception.
T expectOk<T>(Result<T> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final message) => fail(message),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Setup sqflite_ffi for testing
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Printer Paper Size', () {
    const macA = '00:11:22:33:44:55';
    const macB = 'AA:BB:CC:DD:EE:FF';

    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('Default 58mm kalau belum pernah diatur', () async {
      expect(await PrinterPreferences.isPaperMm80(macA), false);
    });

    test('Ukuran tersimpan terpisah per printer', () async {
      await PrinterPreferences.setPaperMm80(macA, true);
      await PrinterPreferences.setPaperMm80(macB, false);

      expect(await PrinterPreferences.isPaperMm80(macA), true);
      expect(await PrinterPreferences.isPaperMm80(macB), false);
    });
  });

  group('Enum <-> kolom DB', () {
    test('Nilai yang dipersist tidak berubah', () {
      // Kalau salah satu expect di bawah gagal, data lama di perangkat yang
      // sudah terpasang jadi tidak terbaca. Jangan "perbaiki" dengan mengubah
      // nilainya.
      expect(PaymentMethod.cash.dbValue, 'TUNAI');
      expect(PaymentMethod.qris.dbValue, 'QRIS');
      expect(PaymentMethod.nonCash.dbValue, 'NON-TUNAI');
      expect(TransactionStatus.paid.dbValue, 'PAID');
      expect(TransactionStatus.completed.dbValue, 'COMPLETED');
      expect(TransactionStatus.cancelled.dbValue, 'CANCELLED');
    });

    test('Status tak dikenal jatuh ke default skema', () {
      expect(TransactionStatus.fromDb('ENTAH'), TransactionStatus.paid);
      expect(TransactionStatus.fromDb(null), TransactionStatus.paid);
    });

    test('Metode bayar tak dikenal dipertahankan apa adanya', () {
      // Baris lama berisi nama channel Midtrans bebas. Kalau ini berubah jadi
      // TUNAI, riwayat transaksi lama jadi salah label.
      final gopay = PaymentMethod.fromDb('GoPay/GoPay Later');
      expect(gopay.dbValue, 'GoPay/GoPay Later');
      expect(gopay.isCash, false);

      expect(PaymentMethod.fromDb(null), PaymentMethod.cash);
      expect(PaymentMethod.fromDb(''), PaymentMethod.cash);
    });

    test('Channel Midtrans dipetakan ke nilai yang disimpan', () {
      expect(PaymentMethod.fromMidtrans('qris'), PaymentMethod.qris);
      expect(
        PaymentMethod.fromMidtrans('bca_va').dbValue,
        'Bank Transfer (VA)',
      );
      expect(PaymentMethod.fromMidtrans('gopay').dbValue, 'GoPay/GoPay Later');
    });
  });

  group('Photobooth Database Tests', () {
    const products = ProductRepository();
    const transactions = TransactionRepository();

    // In-memory DB, rebuilt per test: no path_provider, no shared state.
    setUp(() async {
      await resetDatabase();
      debugDatabasePath = inMemoryDatabasePath;
    });

    tearDown(resetDatabase);

    test('Skema baru punya produk bawaan', () async {
      final seeded = expectOk(await products.all());
      expect(seeded, hasLength(2));
    });

    test('Should create and retrieve products', () async {
      expectOk(
        await products.create(
          const Product(name: 'Test Package', price: 10000),
        ),
      );

      final all = expectOk(await products.all());
      expect(all.any((p) => p.name == 'Test Package'), true);
    });

    test('Should create and retrieve transactions', () async {
      final uuid = const Uuid().v4();
      final queueNumber = expectOk(
        await transactions.create(
          Transaction(
            uuid: uuid,
            items: const [
              TransactionItem(
                productName: 'Test Package',
                productPrice: 10000,
                quantity: 1,
              ),
            ],
            totalPrice: 10000,
            createdAt: DateTime.now(),
          ),
        ),
      );

      expect(queueNumber, greaterThan(0));

      final all = expectOk(await transactions.all());
      final saved = all.firstWhere((t) => t.uuid == uuid);
      expect(saved.items.single.productName, 'Test Package');
      expect(saved.queueNumber, queueNumber);
      expect(saved.status, TransactionStatus.paid);
    });

    test('Redeem sekali berhasil, kedua kali ditolak', () async {
      final uuid = const Uuid().v4();
      expectOk(
        await transactions.create(
          Transaction(
            uuid: uuid,
            items: const [
              TransactionItem(
                productName: 'Test Package',
                productPrice: 10000,
                quantity: 1,
              ),
            ],
            totalPrice: 10000,
            createdAt: DateTime.now(),
          ),
        ),
      );

      expect(expectOk(await transactions.redeem(uuid)), isA<RedeemedOk>());
      expect(
        expectOk(await transactions.redeem(uuid)),
        isA<TicketAlreadyUsed>(),
      );
      expect(
        expectOk(await transactions.redeem('tidak-ada')),
        isA<TicketNotFound>(),
      );
    });
  });
}
