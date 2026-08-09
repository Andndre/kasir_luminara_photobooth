import 'package:flutter_test/flutter_test.dart';
import 'package:luminara_photobooth/core/data/db.dart';
import 'package:luminara_photobooth/core/data/repositories/product_repository.dart';
import 'package:luminara_photobooth/core/data/repositories/transaction_repository.dart';
import 'package:luminara_photobooth/core/data/result.dart';
import 'package:luminara_photobooth/core/domain/domain.dart';
import 'package:luminara_photobooth/core/services/sync_service.dart';
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

  // Ketiga tes penukaran yang dulu ada di sini ikut dihapus bersama
  // TransactionRepository.applyRedemptions. Bukan supaya perubahan ini lolos:
  // riwayat kasir sekarang dibaca langsung dari server, jadi status penukaran
  // datang bersama barisnya dan tidak ada lagi yang perlu disalin ke SQLite.
  // Yang menggantikannya ada di transaction_test.dart, menjaga bahwa baris
  // yang belum sempat naik tidak hilang dari riwayat.

  test('Menghapus meninggalkan nisan untuk dikirim ke server', () async {
    expectOk(await repo.create(sale('a')));
    expectOk(await repo.delete('a'));

    expect(expectOk(await repo.findByUuid('a')), isNull);
    expect(expectOk(await repo.pendingDeletes()), ['a']);

    // Sesudah server mengakuinya, nisannya tidak perlu dikirim lagi.
    expectOk(await repo.clearPendingDeletes(['a']));
    expect(expectOk(await repo.pendingDeletes()), isEmpty);
  });

  /// Dipanggil saat perangkat ini mengambil peran kasir. Perangkat sebelumnya
  /// mungkin sudah mencetak nomor lebih tinggi, dan tiketnya ada di tangan
  /// pelanggan — jadi counter di sini hanya boleh naik, tidak pernah turun.
  group('raiseQueueCounter', () {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    test('menaikkan counter supaya nomor tidak terulang', () async {
      expectOk(await repo.raiseQueueCounter(today, 7));

      expect(expectOk(await repo.create(sale('a'))), 8);
    });

    test('tidak pernah menurunkan counter yang sudah lebih tinggi', () async {
      expect(expectOk(await repo.create(sale('a'))), 1);
      expect(expectOk(await repo.create(sale('b'))), 2);

      // Server menjawab lebih rendah, misalnya karena baris terakhir dihapus.
      expectOk(await repo.raiseQueueCounter(today, 1));

      expect(expectOk(await repo.create(sale('c'))), 3);
    });

    test('nol tidak mengubah apa pun', () async {
      expect(expectOk(await repo.create(sale('a'))), 1);
      expectOk(await repo.raiseQueueCounter(today, 0));

      expect(expectOk(await repo.create(sale('b'))), 2);
    });
  });

  // Katalog tidak lagi ikut di setiap sync — hanya kalau tanda tangannya
  // berbeda. Kalau tanda tangan gagal membedakan dua katalog, perubahan harga
  // atau paket yang dihapus tidak akan pernah sampai server.
  group('Tanda tangan katalog', () {
    String sign(List<Product> products) =>
        SyncService.catalogueSignature(products);

    test('katalog yang sama menghasilkan tanda tangan yang sama', () {
      expect(sign([a1, b2]), sign([a1, b2]));
    });

    test('harga berubah terbaca berbeda', () {
      expect(sign([a1, b2]), isNot(sign([a1, b2.copyWith(price: 12000)])));
    });

    test('nama berubah terbaca berbeda', () {
      expect(sign([a1, b2]), isNot(sign([a1, b2.copyWith(name: 'Cetak')])));
    });

    test('paket dihapus terbaca berbeda', () {
      expect(sign([a1, b2]), isNot(sign([a1])));
    });

    // Nama yang mengandung pemisah tidak boleh bisa meniru baris lain, kalau
    // tidak dua katalog berbeda bisa punya tanda tangan sama dan yang kedua
    // tidak pernah terkirim.
    test('nama berisi spasi tidak menabrak baris lain', () {
      expect(
        sign([const Product(id: 1, name: 'A 1 B', price: 2)]),
        isNot(sign([const Product(id: 1, name: 'A', price: 1)])),
      );
    });

    test('katalog kosong bukan string yang sama dengan katalog berisi', () {
      expect(sign(const []), isNot(sign([a1])));
    });
  });

  group('replaceAll katalog', () {
    const products = ProductRepository();

    test('mengganti seluruh isi, bukan menggabung', () async {
      expectOk(await products.create(a1));
      expectOk(await products.create(b2));

      expectOk(
        await products.replaceAll([
          const Product(id: 9, name: 'Baru', price: 1),
        ]),
      );

      final after = expectOk(await products.all());
      expect(after, [const Product(id: 9, name: 'Baru', price: 1)]);
    });

    test('daftar kosong mengosongkan katalog', () async {
      expectOk(await products.create(a1));
      expectOk(await products.replaceAll(const []));

      expect(expectOk(await products.all()), isEmpty);
    });

    // Riwayat menyimpan nama dan harga sebagai salinan, jadi mengganti katalog
    // tidak boleh menyentuhnya. Kalau ini gugur, laporan kehilangan isinya
    // setiap kali kasir menyegarkan daftar paket.
    test('tidak menyentuh riwayat transaksi', () async {
      expectOk(await repo.create(sale('x')));
      expectOk(await products.replaceAll(const []));

      final history = expectOk(await repo.all());
      expect(history.single.items.single.productName, 'Self Photo 15 Menit');
    });
  });
}

const a1 = Product(id: 1, name: 'Self Photo', price: 50000);
const b2 = Product(id: 2, name: 'Cetak Ulang', price: 10000);
