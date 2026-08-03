import 'package:flutter_test/flutter_test.dart';
import 'package:luminara_photobooth/core/preferences/printer_preferences.dart';
import 'package:luminara_photobooth/model/produk.dart';
import 'package:luminara_photobooth/model/transaksi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
        items: [
          TransaksiItem(
            productName: 'Test Package',
            productPrice: 10000,
            quantity: 1,
          ),
        ],
        totalPrice: 10000,
        createdAt: DateTime.now(),
      );

      await Transaksi.createTransaksi(t);
      final all = await Transaksi.getAllTransaksi();
      expect(all.any((element) => element.uuid == uuid), true);
    });
  });
}
