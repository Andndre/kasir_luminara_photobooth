import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repositories/product_repository.dart';
import '../data/repositories/transaction_repository.dart';
import '../data/result.dart';
import '../domain/product.dart';
import '../helpers/app_log.dart';
import 'auth_service.dart';
import 'cashier_lease_service.dart';
import 'cloud_api.dart';
import 'device_identity.dart';

/// What the app should do with the data straight after logging in.
enum LoginDataPlan {
  /// Perangkat ini kosong dan server punya isi — tarik tanpa bertanya.
  pullFromServer,

  /// Kedua sisi berisi dan tidak sama. Hanya user yang boleh memutuskan.
  ask,

  /// Tidak ada yang perlu ditanyakan; sync latar biasa sudah cukup.
  syncNormally,
}

/// Mendorong isi SQLite perangkat ini ke luminarabali.com.
///
/// Satu arah, dan itulah yang membuatnya aman: **kasir yang membuat, server
/// yang menukarkan.** [push] tidak pernah mengunggah `status`/`redeemed_at`,
/// dan tidak ada yang turun ke sini sama sekali — riwayat dibaca langsung dari
/// server, jadi kedua sisi tidak punya kolom yang bisa berselisih.
class SyncService {
  static final SyncService _instance = SyncService._();
  factory SyncService() => _instance;
  SyncService._();

  static const _api = CloudApi();
  static const _transactions = TransactionRepository();
  static const _products = ProductRepository();

  /// Tanda tangan katalog yang terakhir diterima server, supaya daftar yang
  /// tidak berubah tidak ikut dikirim ulang tiap 15 detik.
  static const _keyCatalogue = 'sync_catalogue_signature';

  /// Kursor-kursor tarikan versi lama. Tidak dipakai lagi sejak sync jadi satu
  /// arah, tapi tetap dibuang di [reset]: perangkat yang diturunkan ke build
  /// lama akan memakainya lagi, dan kursor milik akun sebelumnya membuatnya
  /// melewatkan penukaran.
  static const _legacyCursors = ['sync_pull_cursor', 'sync_redemption_cursor'];

  /// Matches the server's `max:500` cap with room to spare.
  static const _batchSize = 200;

  /// How often the background loop runs.
  ///
  /// Yang dikerjakannya cuma mendorong sisa yang belum naik dan membawa detak
  /// sewa terhadap TTL 90 detik. Bukan untuk menunggu kabar apa pun — tidak ada
  /// lagi yang ditunggu dari server di sini.
  static const interval = Duration(seconds: 15);

  Timer? _timer;

  /// Guards against a slow round still running when the next tick fires, which
  /// is how a polling loop turns into an ever-growing pile of requests.
  bool _busy = false;

  void start() {
    _timer ??= Timer.periodic(interval, (_) => runOnce());
    unawaited(runOnce());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> runOnce() async {
    if (_busy || !AuthService().isLoggedIn) return;
    _busy = true;
    try {
      // Dicatat, bukan ditelan. Sebelumnya hasil kedua panggilan ini dibuang,
      // jadi satu baris lama yang ditolak server bikin seluruh riwayat diam
      // saja tidak terkirim tanpa jejak apa pun.
      switch (await push()) {
        case Err(:final error):
          AppLog.error('Sync push gagal: $error');
          // Tidak terjangkau, bukan kehilangan sewa. Perbedaannya penting:
          // yang satu tetap boleh menjual, yang lain tidak.
          CashierLeaseService().onUnreachable();
        case Ok():
          break;
      }
      // Tidak ada tarikan. Sync ini satu arah sejak riwayat kasir dibaca
      // langsung dari server — status penukaran ikut turun bersama barisnya,
      // jadi tidak ada lagi yang perlu disalin ke SQLite lokal.
    } finally {
      _busy = false;
    }
  }

  /// Sisa yang belum sampai server, untuk ditampilkan di Setelan.
  Future<int> pendingCount() async =>
      (await _transactions.unsyncedCount()).valueOrNull ?? 0;

  /// What to do with the data right after a successful login.
  ///
  /// Perbandingannya sengaja cuma jumlah baris, bukan checksum: pertanyaannya
  /// hanya "perlukah user ditanya", dan jumlah sudah menjawab itu. Dua sisi
  /// dengan jumlah sama tapi isi berbeda akan lolos sebagai [syncNormally] —
  /// batas yang diketahui; naikkan ke checksum kalau ternyata jadi masalah.
  Future<LoginDataPlan> planAfterLogin() async {
    final local = (await _transactions.count()).valueOrNull ?? 0;

    final summary = await _api.summary();
    if (summary case Err(:final error)) {
      // Server tidak terjawab bukan alasan menahan user di layar login.
      AppLog.error('Gagal membaca ringkasan server: $error');
      return LoginDataPlan.syncNormally;
    }

    final server = (summary as Ok).value.transactions as int;

    if (local == 0 && server > 0) return LoginDataPlan.pullFromServer;
    if (local > 0 && server > 0 && local != server) return LoginDataPlan.ask;
    return LoginDataPlan.syncNormally;
  }

  /// Uploads everything not yet accepted by the server, oldest first.
  ///
  /// Call this and *await* it at checkout, before printing the ticket: the
  /// customer walks from the till to the booth in seconds, and a ticket the
  /// server has never seen cannot be scanned there.
  ///
  /// Returns how many transactions were uploaded.
  Future<Result<int>> push() async {
    var uploaded = 0;

    // Katalog ikut hanya kalau memang berubah sejak terakhir server menerimanya.
    // Sebelumnya ia ikut di setiap putaran pertama — 5.760 salinan daftar yang
    // sama per perangkat per hari, untuk daftar yang berubah beberapa kali
    // setahun.
    final prefs = await SharedPreferences.getInstance();
    final catalogue = (await _products.all()).valueOrNull ?? const <Product>[];
    final signature = catalogueSignature(catalogue);
    final catalogueChanged = signature != prefs.getString(_keyCatalogue);

    // Berhenti setelah beberapa putaran walaupun masih ada sisa: perangkat yang
    // baru login bisa punya ribuan baris, dan checkout tidak boleh menunggu
    // seluruh riwayat terkirim. Sisanya diambil tick berikutnya.
    for (var round = 0; round < 5; round++) {
      final batch = await _transactions.unsynced(limit: _batchSize);
      switch (batch) {
        case Err(:final message, :final error, :final stackTrace):
          return Err(message, error, stackTrace);
        case Ok(value: final pending):
          // Putaran pertama tetap dikirim walau tidak ada transaksi tertunda —
          // katalog produk ikut di sana, dan sebelumnya produk tidak pernah
          // sampai server di perangkat yang riwayatnya sudah tersinkron semua.
          if (pending.isEmpty && round > 0) return Ok(uploaded);

          // Produk dan penghapusan ikut hanya di putaran pertama — keduanya
          // daftar pendek yang tidak berubah antar batch. null di putaran
          // berikutnya berarti "jangan sentuh katalog", bukan "katalog kosong".
          final products = round == 0 && catalogueChanged ? catalogue : null;
          final deleted = round == 0
              ? (await _transactions.pendingDeletes()).valueOrNull ??
                    const <String>[]
              : const <String>[];

          switch (await _api.push(
            pending,
            products: products,
            deleted: deleted,
            // Detak sewa menumpang di sini. Hanya di putaran pertama, supaya
            // satu batch besar tidak terhitung sebagai beberapa detak.
            deviceId: round == 0 ? await DeviceIdentity.id() : null,
          )) {
            case Err(:final message, :final error, :final stackTrace):
              return Err(message, error, stackTrace);
            case Ok(value: final leaseAnswer):
              if (round == 0) {
                CashierLeaseService().onHeartbeat(leaseAnswer);

                // Hanya dicatat kalau perangkat ini memegang sewa. Server
                // mengabaikan bagian PENGHAPUSAN katalog dari perangkat yang
                // sudah kehilangan peran, jadi mencatatnya di sini berarti
                // paket yang dihapus tidak akan pernah dicoba kirim lagi.
                if (catalogueChanged && leaseAnswer == 'held') {
                  await prefs.setString(_keyCatalogue, signature);
                }
              }
              final marked = await _transactions.markSynced(
                pending.map((t) => t.uuid).toList(),
                DateTime.now(),
              );
              if (marked case Err(
                :final message,
                :final error,
                :final stackTrace,
              )) {
                return Err(message, error, stackTrace);
              }

              // Nisan dibuang hanya setelah server mengakuinya. Kalau urutannya
              // dibalik, satu kegagalan kirim membuat penghapusan itu hilang
              // dari catatan dan poll berikutnya menghidupkan barisnya lagi.
              if (deleted.isNotEmpty) {
                await _transactions.clearPendingDeletes(deleted);
              }

              uploaded += pending.length;
              if (pending.isEmpty) return Ok(uploaded);
          }
      }
    }
    return Ok(uploaded);
  }

  /// Fingerprints the catalogue, to tell "berubah" from "sama saja".
  ///
  /// Daftarnya belasan baris, jadi disimpan mentah — bukan hash. Tidak ada
  /// tabrakan yang mungkin, dan kalau suatu saat ada yang perlu tahu kenapa
  /// katalog terkirim ulang, isinya bisa dibaca langsung dari preferences.
  @visibleForTesting
  static String catalogueSignature(List<Product> products) =>
      products.map((p) => '${p.id} ${p.name} ${p.price}').join('\n');

  /// Pushes the local catalogue, then takes the server's answer as the truth.
  ///
  /// Dorong dulu baru tarik, dan urutannya bukan selera: kalau ditarik lebih
  /// dulu, paket yang baru dibuat dan belum sempat terkirim akan tersapu
  /// jawaban server yang belum mengenalnya.
  ///
  /// Dipanggil dari tarik-untuk-menyegarkan di halaman Paket, bukan dari loop
  /// 15 detik — katalog berubah beberapa kali setahun, dan satu-satunya
  /// perangkat yang mengubahnya sudah memilikinya.
  Future<Result<void>> refreshProducts() async {
    if (await push() case Err(
      :final message,
      :final error,
      :final stackTrace,
    )) {
      return Err(message, error, stackTrace);
    }

    final remote = await _api.products();
    switch (remote) {
      case Err(:final message, :final error, :final stackTrace):
        return Err(message, error, stackTrace);
      case Ok(value: final products):
        final saved = await _products.replaceAll(products);
        if (saved case Err(:final message, :final error, :final stackTrace)) {
          return Err(message, error, stackTrace);
        }

        // Lokal dan server sekarang identik, jadi dicatat supaya push
        // berikutnya tidak mengirim balik daftar yang baru saja diterima.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyCatalogue, catalogueSignature(products));
        return const Ok(null);
    }
  }

  /// Cursor must be dropped along with the account — the next login may be a
  /// different one, whose rows all predate this cursor.
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _legacyCursors) {
      await prefs.remove(key);
    }
    // Ikut dibuang: tanpa ini, tanda tangan katalog akun lama membuat katalog
    // akun baru dianggap "sudah terkirim" dan tidak pernah sampai server.
    await prefs.remove(_keyCatalogue);
    AppLog.info('Sync cursor direset');
  }
}
