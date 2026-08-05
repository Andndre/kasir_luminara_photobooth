import 'package:flutter/foundation.dart';

import '../data/repositories/transaction_repository.dart';
import '../data/result.dart';
import '../helpers/app_log.dart';
import 'auth_service.dart';
import 'cloud_api.dart';
import 'device_identity.dart';

/// Keadaan peran kasir di perangkat ini.
///
/// Hanya dua di antaranya yang boleh menjual, dan itu sengaja dipisah supaya
/// setiap tempat yang menanyakannya harus memilih secara sadar.
enum CashierLeaseState {
  /// Klaim sedang dikirim, atau belum pernah dikirim.
  checking,

  /// Server mengakui perangkat ini sebagai kasir.
  active,

  /// Server tidak terjangkau. Tetap menjual — kasir tidak boleh mati karena
  /// Wi-Fi venue mati — tapi perannya tidak bisa dipastikan lagi.
  activeOffline,

  /// Perangkat lain sedang memegangnya dan masih hidup.
  locked,

  /// Perangkat lain mengambil alih. Peran ini hilang sampai diklaim lagi.
  released;

  /// Satu-satunya pertanyaan yang benar-benar penting bagi layar kasir.
  bool get canSell => this == active || this == activeOffline;
}

/// Siapa yang sedang memegang peran kasir, kalau bukan kita.
typedef LeaseHolder = ({String deviceName, DateTime? heartbeatAt});

/// Menjaga aturan **satu perangkat kasir per akun**.
///
/// Aturan itulah yang membuat sisa sistem tidak punya konflik untuk
/// diselesaikan: nomor antrian tidak bisa bentrok, tidak ada yang perlu
/// di-merge, penghapusan tidak punya lawan.
///
/// Yang TIDAK dijaga, dan tidak bisa dijaga: perangkat yang kehilangan internet
/// tetap menjual. Sewa ini mencegah dua kasir karena kelalaian — HP cadangan
/// yang menyala di laci, dua orang membuka aplikasi — bukan karena jaringan
/// terbelah. Menutup yang terakhir berarti kasir mati saat internet mati, dan
/// itu lebih mahal daripada masalah yang dicegahnya.
class CashierLeaseService extends ChangeNotifier {
  static final CashierLeaseService _instance = CashierLeaseService._();
  factory CashierLeaseService() => _instance;
  CashierLeaseService._();

  static const _api = CloudApi();

  CashierLeaseState _state = CashierLeaseState.checking;
  CashierLeaseState get state => _state;

  LeaseHolder? _holder;

  /// Terisi hanya saat [state] adalah [CashierLeaseState.locked].
  LeaseHolder? get holder => _holder;

  void _emit(CashierLeaseState next, {LeaseHolder? holder}) {
    if (_state == next && _holder == holder) return;
    _state = next;
    _holder = holder;
    notifyListeners();
  }

  /// Mengklaim peran kasir. Panggil saat masuk mode kasir.
  ///
  /// [force] merebutnya dari perangkat yang masih hidup — hanya boleh setelah
  /// user menyatakannya secara tegas, karena dua kasir yang sama-sama merasa
  /// berhak adalah persis keadaan yang mau dicegah di sini.
  Future<void> claim({bool force = false, String? queueDate}) async {
    if (!AuthService().isLoggedIn) return;

    _emit(CashierLeaseState.checking);

    final result = await _api.claimCashier(
      deviceId: await DeviceIdentity.id(),
      deviceName: await DeviceIdentity.name(),
      queueDate: queueDate ?? DateTime.now().toIso8601String().substring(0, 10),
      force: force,
    );

    switch (result) {
      case Ok(value: final claim):
        // Sebelum menandai aktif: perangkat sebelumnya mungkin sudah mencetak
        // nomor yang lebih tinggi, dan tiket itu ada di tangan pelanggan.
        // Menjual dulu lalu menyelaraskan berarti satu nomor kembar.
        await const TransactionRepository().raiseQueueCounter(
          claim.queue.date,
          claim.queue.lastNumber,
        );
        _emit(CashierLeaseState.active);
        AppLog.info('Peran kasir diambil perangkat ini');

      case Err(error: LeaseHeldByOther(:final holder)):
        _emit(CashierLeaseState.locked, holder: holder);
        AppLog.info('Peran kasir sedang dipegang ${holder.deviceName}');

      case Err(:final error):
        // Server tak terjangkau bukan alasan berhenti berjualan. Perannya
        // dianggap masih milik kita sampai ada kabar sebaliknya.
        _emit(CashierLeaseState.activeOffline);
        AppLog.error('Gagal mengklaim peran kasir: $error');
    }
  }

  /// Dipanggil [SyncService] dengan jawaban `cashier_lease` dari tiap sync.
  ///
  /// Di sinilah perangkat yang perannya direbut akhirnya tahu — sync memang
  /// sudah berjalan tiap 15 detik, jadi tidak ada timer kedua untuk ini.
  void onHeartbeat(String? answer) {
    switch (answer) {
      case 'held':
        _emit(CashierLeaseState.active);
      case 'lost':
        if (_state != CashierLeaseState.released) {
          AppLog.error('Peran kasir diambil alih perangkat lain');
        }
        _emit(CashierLeaseState.released);
      case _:
        // null: perangkat ini tidak sedang meminta detak (mode verifier, atau
        // server versi lama). Jangan diartikan sebagai kehilangan sewa.
        break;
    }
  }

  /// Sync gagal menghubungi server. Yang sudah aktif turun ke offline, yang
  /// sudah kehilangan peran tidak boleh naik lagi diam-diam.
  void onUnreachable() {
    if (_state == CashierLeaseState.active) {
      _emit(CashierLeaseState.activeOffline);
    }
  }

  /// Melepas peran. Dipanggil saat logout atau pindah ke mode verifier.
  Future<void> release() async {
    if (!AuthService().isLoggedIn) return;

    // Hasilnya sengaja diabaikan: kalau server tak terjangkau, sewanya akan
    // basi sendiri setelah TTL. Menahan logout karena ini tidak masuk akal.
    await _api.releaseCashier(deviceId: await DeviceIdentity.id());
    _emit(CashierLeaseState.checking);
  }

  @visibleForTesting
  void debugSetState(CashierLeaseState state, {LeaseHolder? holder}) =>
      _emit(state, holder: holder);
}

/// Ditandai terpisah dari kegagalan jaringan: yang satu berarti "perangkat lain
/// sedang jadi kasir", yang lain berarti "kami tidak tahu". Menyamakan keduanya
/// akan membuat internet yang putus terlihat seperti perangkat lain merebut.
class LeaseHeldByOther implements Exception {
  final LeaseHolder holder;
  const LeaseHeldByOther(this.holder);

  @override
  String toString() => 'Peran kasir dipegang ${holder.deviceName}';
}
