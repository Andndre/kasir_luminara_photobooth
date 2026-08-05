import 'package:flutter_test/flutter_test.dart';
import 'package:luminara_photobooth/core/services/cashier_lease_service.dart';

/// Menahan aturan "satu kasir per akun" di sisi perangkat.
///
/// Yang dijaga di sini bukan siapa yang menang klaim — itu urusan server — tapi
/// perbedaan antara **tidak terjangkau** dan **kehilangan peran**. Menyamakan
/// keduanya berarti salah satu dari dua bencana: kasir berhenti melayani karena
/// Wi-Fi venue mati, atau dua perangkat menjual dengan nomor antrian yang sama.
void main() {
  // AppLog menulis ke SQLite dari dalam transisi keadaan. Kegagalannya memang
  // ditelan, tapi tanpa binding ia menelannya sambil berisik.
  TestWidgetsFlutterBinding.ensureInitialized();

  final lease = CashierLeaseService();

  setUp(() => lease.debugSetState(CashierLeaseState.checking));

  test('hanya aktif dan aktif-offline yang boleh menjual', () {
    expect(CashierLeaseState.active.canSell, isTrue);
    expect(CashierLeaseState.activeOffline.canSell, isTrue);

    expect(CashierLeaseState.locked.canSell, isFalse);
    expect(CashierLeaseState.released.canSell, isFalse);
    // Klaim belum terjawab bukan izin menjual.
    expect(CashierLeaseState.checking.canSell, isFalse);
  });

  test('server tak terjangkau menurunkan ke offline, bukan melepas', () {
    lease.debugSetState(CashierLeaseState.active);
    lease.onUnreachable();

    expect(lease.state, CashierLeaseState.activeOffline);
    // Inti dari seluruh rancangan: internet mati tidak menghentikan penjualan.
    expect(lease.state.canSell, isTrue);
  });

  test('yang sudah kehilangan peran tidak naik lagi karena jaringan putus', () {
    lease.debugSetState(CashierLeaseState.released);
    lease.onUnreachable();

    expect(lease.state, CashierLeaseState.released);
  });

  test('jawaban lost menghentikan penjualan', () {
    lease.debugSetState(CashierLeaseState.active);
    lease.onHeartbeat('lost');

    expect(lease.state, CashierLeaseState.released);
    expect(lease.state.canSell, isFalse);
  });

  test('jawaban kosong tidak diartikan sebagai kehilangan sewa', () {
    lease.debugSetState(CashierLeaseState.active);
    // null datang dari mode verifier, atau dari server yang belum tahu soal
    // sewa sama sekali. Mengartikannya "lost" akan mematikan kasir setiap kali
    // aplikasi bertemu server versi lama.
    lease.onHeartbeat(null);

    expect(lease.state, CashierLeaseState.active);
  });

  test('perubahan keadaan memberi tahu pendengarnya sekali per perubahan', () {
    var notifications = 0;
    void listener() => notifications++;

    lease.debugSetState(CashierLeaseState.active);
    lease.addListener(listener);
    addTearDown(() => lease.removeListener(listener));

    lease.onHeartbeat('held'); // sama, tidak perlu membangun ulang bilahnya
    expect(notifications, 0);

    lease.onHeartbeat('lost');
    expect(notifications, 1);
  });
}
