import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luminara_photobooth/features/transaction/pages/transaction_page.dart';

/// showDateRangePicker melempar assertion kalau initialDateRange keluar dari
/// [firstDate, lastDate] — dan di aplikasi ini assertion-nya ketelan try/catch
/// sehingga cuma tampil "Gagal membuka date picker".
void main() {
  final firstDate = DateTime(2020);
  final lastDate = DateTime(2026, 8, 3);

  test('null tetap null (filter "Semua Data")', () {
    expect(clampRange(null, firstDate, lastDate), isNull);
  });

  test('rentang yang sudah valid tidak diubah', () {
    final r = DateTimeRange(
      start: DateTime(2026, 8, 1),
      end: DateTime(2026, 8, 2),
    );
    final clamped = clampRange(r, firstDate, lastDate)!;
    expect(clamped.start, r.start);
    expect(clamped.end, r.end);
  });

  test('"Bulan Ini": akhir bulan di masa depan dipotong ke lastDate', () {
    // Inilah yang bikin picker gagal terbuka.
    final r = DateTimeRange(
      start: DateTime(2026, 8, 1),
      end: DateTime(2026, 8, 31),
    );
    final clamped = clampRange(r, firstDate, lastDate)!;
    expect(clamped.end, lastDate);
    expect(clamped.end.isAfter(lastDate), isFalse);
  });

  test('mulai sebelum firstDate dinaikkan', () {
    final r = DateTimeRange(
      start: DateTime(2019, 1, 1),
      end: DateTime(2026, 8, 2),
    );
    final clamped = clampRange(r, firstDate, lastDate)!;
    expect(clamped.start, firstDate);
  });

  test('rentang seluruhnya di masa depan tidak jadi terbalik', () {
    final r = DateTimeRange(
      start: DateTime(2027, 1, 1),
      end: DateTime(2027, 2, 1),
    );
    final clamped = clampRange(r, firstDate, lastDate)!;
    expect(clamped.start.isAfter(clamped.end), isFalse);
    expect(clamped.end.isAfter(lastDate), isFalse);
  });
}
