import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:luminara_photobooth/core/domain/domain.dart';
import 'package:luminara_photobooth/features/transaction/pages/transaction_page.dart';

/// Riwayat kasir dibaca dari server supaya tidak lagi berbeda antar perangkat.
///
/// Yang dijaga di sini adalah jaring pengamannya: baris yang belum sempat naik
/// tidak boleh hilang dari layar. Kalau tes ini gugur, penjualan yang dibuat
/// saat internet putus lenyap dari riwayat kasirnya sendiri — uang yang sudah
/// diterima tapi tidak terlihat, dan total pemasukan yang salah tanpa terlihat
/// salah.
void main() {
  Transaction sale(String uuid, DateTime at) => Transaction(
    uuid: uuid,
    items: const [
      TransactionItem(
        productName: 'Self Photo 15 Menit',
        productPrice: 50000,
        quantity: 1,
      ),
    ],
    totalPrice: 50000,
    createdAt: at,
  );

  final senin = DateTime(2026, 8, 3, 10);
  final selasa = DateTime(2026, 8, 4, 10);
  final rabu = DateTime(2026, 8, 5, 10);

  List<String> merge(
    List<Transaction> remote,
    List<Transaction> pending, [
    DateTimeRange? range,
  ]) => TransactionHistoryView.mergePending(
    remote,
    pending,
    range,
  ).map((t) => t.uuid).toList();

  test('baris yang belum naik ikut tampil', () {
    expect(merge([sale('a', senin)], [sale('b', selasa)]), ['b', 'a']);
  });

  test('baris yang sudah sampai server tidak jadi dua', () {
    expect(merge([sale('a', senin)], [sale('a', senin)]), ['a']);
  });

  // Salinan server menang: status penukaran ditentukan server dan tidak pernah
  // ikut naik, jadi salinan lokal bisa lebih tua walau uuid-nya sama.
  test('untuk uuid yang sama, baris server yang dipakai', () {
    final dariServer = sale(
      'a',
      senin,
    ).copyWith(status: TransactionStatus.completed);
    final merged = TransactionHistoryView.mergePending(
      [dariServer],
      [sale('a', senin)],
      null,
    );

    expect(merged.single.status, TransactionStatus.completed);
  });

  test('terurut terbaru dulu, bukan server dulu lalu lokal', () {
    expect(merge([sale('a', senin)], [sale('c', rabu), sale('b', selasa)]), [
      'c',
      'b',
      'a',
    ]);
  });

  group('filter tanggal', () {
    final rentang = DateTimeRange(start: selasa, end: selasa);

    test('baris tertunda di luar rentang tidak ikut', () {
      expect(merge([], [sale('a', senin)], rentang), isEmpty);
    });

    test('baris tertunda di dalam rentang ikut', () {
      expect(merge([], [sale('a', selasa)], rentang), ['a']);
    });

    // Rentangnya dibandingkan per hari, bukan per detik: "Hari Ini" memakai
    // DateTime.now() di kedua ujung, jadi perbandingan mentah akan membuang
    // transaksi yang dibuat pagi tadi.
    test('jam tidak memotong hari yang sama', () {
      final siang = DateTimeRange(
        start: DateTime(2026, 8, 4, 14),
        end: DateTime(2026, 8, 4, 14),
      );
      expect(merge([], [sale('a', DateTime(2026, 8, 4, 9))], siang), ['a']);
    });

    test('tanpa rentang berarti semua tanggal', () {
      expect(merge([], [sale('a', senin), sale('b', rabu)]), ['b', 'a']);
    });
  });
}
