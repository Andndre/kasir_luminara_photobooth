import 'package:flutter_test/flutter_test.dart';
import 'package:luminara_photobooth/features/verifier/pages/live_queue_page.dart';

/// Antrean tidak lagi ditarik otomatis, jadi label umurnya adalah satu-satunya
/// hal yang memberi tahu petugas bahwa daftarnya sudah basi. Kalau ia salah,
/// daftar sepuluh menit lalu akan terbaca seperti keadaan sekarang.
void main() {
  group('Label umur antrean', () {
    test('belum pernah dimuat tidak berpura-pura punya umur', () {
      expect(queueAgeLabel(null), contains('belum pernah'));
    });

    test('di bawah 30 detik dianggap baru', () {
      expect(queueAgeLabel(const Duration(seconds: 29)), contains('baru saja'));
    });

    test('30 detik sudah tidak "baru saja" lagi', () {
      final label = queueAgeLabel(const Duration(seconds: 30));
      expect(label, isNot(contains('baru saja')));
      expect(label, contains('kurang dari semenit'));
    });

    test('menit disebut angkanya', () {
      expect(queueAgeLabel(const Duration(minutes: 8)), contains('8 menit'));
    });

    test('satu jam tidak dilaporkan sebagai 60 menit', () {
      final label = queueAgeLabel(const Duration(minutes: 60));
      expect(label, contains('jam'));
      expect(label, isNot(contains('60 menit')));
    });
  });
}
