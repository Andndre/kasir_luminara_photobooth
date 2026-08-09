import 'package:flutter_test/flutter_test.dart';
import 'package:luminara_photobooth/core/services/update_service.dart';

/// Perbandingan versi yang salah arah adalah cara paling rapi untuk menyuruh
/// seluruh perangkat di venue memasang build yang lebih tua.
void main() {
  group('Deteksi versi baru', () {
    test('patch naik terdeteksi', () {
      expect(UpdateService.isNewer('1.5.3', '1.5.2'), isTrue);
    });

    test('versi sama bukan pembaruan', () {
      expect(UpdateService.isNewer('1.5.2', '1.5.2'), isFalse);
    });

    test('versi lebih tua tidak pernah ditawarkan', () {
      expect(UpdateService.isNewer('1.4.9', '1.5.2'), isFalse);
    });

    test('minor menang atas patch, bukan dibandingkan sebagai teks', () {
      // '1.10.0' < '1.9.0' kalau dibandingkan sebagai string.
      expect(UpdateService.isNewer('1.10.0', '1.9.0'), isTrue);
      expect(UpdateService.isNewer('1.9.0', '1.10.0'), isFalse);
    });

    test('versi pendek dianggap berakhiran nol', () {
      expect(UpdateService.isNewer('2.0', '1.9.9'), isTrue);
      expect(UpdateService.isNewer('1.5', '1.5.1'), isFalse);
    });

    test('tag yang tidak terbaca gagal ke arah aman', () {
      // Bukan "ada versi baru bernama nightly", tapi "tidak ada apa-apa".
      expect(UpdateService.isNewer('nightly', '1.5.2'), isFalse);
      expect(UpdateService.isNewer('', '1.5.2'), isFalse);
    });
  });
}
