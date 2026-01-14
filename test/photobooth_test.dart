import 'package:flutter_test/flutter_test.dart';
import 'package:luminara_photobooth/model/produk.dart';
import 'package:luminara_photobooth/model/transaksi.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Setup sqflite_ffi for testing
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Photobooth Database Tests', () {
    test('Should create and retrieve products', () async {
      final p = Produk(name: 'Test Package', price: 10000);
      final id = await Produk.createProduk(p);
      expect(id, isNotNull);

      final all = await Produk.getAllProduk();
      expect(all.any((element) => element.name == 'Test Package'), true);
    });

    test('Should create and retrieve transactions', () async {
      final uuid = Transaksi.generateUuid();
      final t = Transaksi(
        uuid: uuid,
        productName: 'Test Package',
        productPrice: 10000,
        createdAt: DateTime.now(),
      );

      await Transaksi.createTransaksi(t);
      final all = await Transaksi.getAllTransaksi();
      expect(all.any((element) => element.uuid == uuid), true);
    });
  });
}
