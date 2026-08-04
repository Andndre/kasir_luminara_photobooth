import 'package:flutter_test/flutter_test.dart';
import 'package:luminara_photobooth/core/domain/product.dart';
import 'package:luminara_photobooth/features/cashier/blocs/cart.dart';
import 'package:luminara_photobooth/features/cashier/cash_denominations.dart';

/// Logika yang dulu tertanam di dalam closure builder dialog kasir, jadi tidak
/// bisa diuji tanpa merender widget.
void main() {
  group('CashDenominations.suggest', () {
    test('Uang pas selalu jadi saran pertama', () {
      expect(CashDenominations.suggest(12000).first, 12000);
      expect(CashDenominations.suggest(50000).first, 50000);
    });

    test('Membulatkan ke atas per pecahan', () {
      // 12.000 -> 15.000 (3x5rb), 20.000 (2x10rb), lalu pecahan di atasnya.
      expect(CashDenominations.suggest(12000), [
        12000,
        15000,
        20000,
        50000,
        100000,
      ]);
    });

    test('Total lebih kecil dari pecahan terkecil', () {
      expect(CashDenominations.suggest(3000), [
        3000,
        5000,
        10000,
        20000,
        50000,
        100000,
      ]);
    });

    test('Tidak pernah melebihi batas jumlah saran', () {
      for (final total in [1, 3000, 12345, 87500, 1000000]) {
        expect(
          CashDenominations.suggest(total).length,
          lessThanOrEqualTo(CashDenominations.maxSuggestions),
        );
      }
    });

    test('Saran selalu menutupi tagihan dan urut naik', () {
      final suggestions = CashDenominations.suggest(87500);
      expect(suggestions.every((s) => s >= 87500), true);
      for (var i = 1; i < suggestions.length; i++) {
        expect(suggestions[i], greaterThan(suggestions[i - 1]));
      }
    });

    test('Total nol atau negatif tidak menyarankan apa pun', () {
      expect(CashDenominations.suggest(0), isEmpty);
      expect(CashDenominations.suggest(-1), isEmpty);
    });
  });

  group('Cart', () {
    const paketA = Product(id: 1, name: 'Self Photo', price: 50000);
    const paketB = Product(id: 2, name: 'Wide Angle', price: 75000);

    test('Keranjang baru kosong', () {
      const cart = Cart();
      expect(cart.isEmpty, true);
      expect(cart.totalPrice, 0);
      expect(cart.totalItems, 0);
    });

    test('Menambah item menghitung total', () {
      final cart = const Cart().adjust(paketA, 1).adjust(paketB, 2);
      expect(cart.totalItems, 3);
      expect(cart.totalPrice, 50000 + 75000 * 2);
    });

    test('Menambah produk yang sama menaikkan qty, bukan baris baru', () {
      final cart = const Cart().adjust(paketA, 1).adjust(paketA, 1);
      expect(cart.lines, hasLength(1));
      expect(cart.quantityOf(paketA), 2);
    });

    test('Qty turun ke nol menghapus barisnya', () {
      final cart = const Cart().adjust(paketA, 2).adjust(paketA, -2);
      expect(cart.isEmpty, true);
      expect(cart.quantityOf(paketA), 0);
    });

    test('Qty tidak pernah negatif', () {
      final cart = const Cart().adjust(paketA, 1).adjust(paketA, -5);
      expect(cart.quantityOf(paketA), 0);
      expect(cart.totalPrice, 0);
    });

    test('Mengurangi produk yang tidak ada tidak mengubah apa pun', () {
      final cart = const Cart().adjust(paketA, -1);
      expect(cart.isEmpty, true);
    });

    test('Item transaksi memotret nama dan harga saat penjualan', () {
      final items = const Cart().adjust(paketA, 3).toTransactionItems();
      expect(items, hasLength(1));
      expect(items.single.productName, 'Self Photo');
      expect(items.single.productPrice, 50000);
      expect(items.single.quantity, 3);
      expect(items.single.subtotal, 150000);
    });

    test('Keranjang tidak berubah saat di-adjust (immutable)', () {
      final awal = const Cart().adjust(paketA, 1);
      final lanjut = awal.adjust(paketA, 1);
      expect(awal.quantityOf(paketA), 1);
      expect(lanjut.quantityOf(paketA), 2);
    });
  });
}
