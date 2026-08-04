import 'package:flutter_test/flutter_test.dart';
import 'package:luminara_photobooth/core/domain/server_address.dart';

/// Dulu tiap layar melakukan split(':') + int.parse sendiri, dan int.parse
/// melempar exception tak tertangkap untuk input seperti "192.168.1.5:abc".
void main() {
  group('ServerAddress.tryParse', () {
    test('Host saja memakai port bawaan', () {
      final address = ServerAddress.tryParse('192.168.1.5');
      expect(address, const ServerAddress('192.168.1.5', 3000));
    });

    test('Host dengan port eksplisit', () {
      expect(
        ServerAddress.tryParse('192.168.1.5:8080'),
        const ServerAddress('192.168.1.5', 8080),
      );
    });

    test('Spasi di sekitar input diabaikan', () {
      expect(
        ServerAddress.tryParse('  192.168.1.5 : 8080  '),
        const ServerAddress('192.168.1.5', 8080),
      );
    });

    test('Port bukan angka ditolak, bukan melempar', () {
      expect(ServerAddress.tryParse('192.168.1.5:abc'), isNull);
      expect(ServerAddress.tryParse('192.168.1.5:'), isNull);
    });

    test('Port di luar rentang ditolak', () {
      expect(ServerAddress.tryParse('10.0.0.1:0'), isNull);
      expect(ServerAddress.tryParse('10.0.0.1:70000'), isNull);
      expect(ServerAddress.tryParse('10.0.0.1:-1'), isNull);
    });

    test('Input kosong ditolak', () {
      expect(ServerAddress.tryParse(''), isNull);
      expect(ServerAddress.tryParse('   '), isNull);
      expect(ServerAddress.tryParse(':3000'), isNull);
    });

    test('toString bisa dibaca balik oleh tryParse', () {
      const original = ServerAddress('192.168.1.5', 3000);
      expect(ServerAddress.tryParse(original.toString()), original);
    });
  });
}
