import 'package:flutter_test/flutter_test.dart';
import 'package:luminara_photobooth/core/services/auth_service.dart';

/// Login yang gagal harus memberi tahu KENAPA. Versi lama mengurai body
/// sebelum memeriksa status, jadi setiap penolakan yang bodinya bukan JSON
/// jatuh ke pesan yang sama: "Gagal masuk". Di lapangan itu membuat blokir
/// firewall tidak bisa dibedakan dari password salah.
void main() {
  group('Pesan gagal masuk', () {
    test('422 Laravel diteruskan apa adanya', () {
      expect(
        AuthService.loginErrorMessage(
          422,
          '{"message":"Email atau password salah"}',
        ),
        'Email atau password salah',
      );
    });

    test('errors per-field dipakai lebih dulu dari message umum', () {
      expect(
        AuthService.loginErrorMessage(
          422,
          '{"message":"The given data was invalid.",'
              '"errors":{"email":["Email wajib diisi"]}}',
        ),
        'Email wajib diisi',
      );
    });

    test('403 HTML dari firewall tidak lagi jadi "Gagal masuk" polos', () {
      final message = AuthService.loginErrorMessage(
        403,
        '<html><head><title>403 Forbidden</title></head></html>',
      );
      expect(message, contains('403'));
      expect(message, contains('firewall'));
    });

    test('429 menyebut tunggu, bukan kredensial', () {
      expect(AuthService.loginErrorMessage(429, ''), contains('Tunggu'));
    });

    test('status tak dikenal tetap membawa angkanya', () {
      expect(
        AuthService.loginErrorMessage(502, '<html>bad gateway'),
        contains('502'),
      );
    });

    test('401 saat login berarti kredensial, bukan sesi habis', () {
      // Ini satu-satunya panggilan yang memang belum punya sesi, jadi pesan
      // umum "Sesi berakhir, silakan masuk lagi" justru menyesatkan di sini.
      final message = AuthService.loginErrorMessage(401, '');
      expect(message, contains('password'));
      expect(message, isNot(contains('Sesi berakhir')));
    });
  });
}
