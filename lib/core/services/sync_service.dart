import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/data_refresh.dart';
import '../data/repositories/product_repository.dart';
import '../data/repositories/transaction_repository.dart';
import '../data/result.dart';
import '../domain/product.dart';
import '../helpers/app_log.dart';
import 'auth_service.dart';
import 'cloud_api.dart';

/// What the app should do with the data straight after logging in.
enum LoginDataPlan {
  /// Perangkat ini kosong dan server punya isi — tarik tanpa bertanya.
  pullFromServer,

  /// Kedua sisi berisi dan tidak sama. Hanya user yang boleh memutuskan.
  ask,

  /// Tidak ada yang perlu ditanyakan; sync latar biasa sudah cukup.
  syncNormally,
}

/// Keeps the local SQLite and luminarabali.com in step.
///
/// The split that makes this safe: **the cashier creates, the server redeems.**
/// [push] therefore never uploads `status`/`redeemed_at`, and [pull] never
/// overwrites a row this device created — the two can't disagree about a field.
class SyncService {
  static final SyncService _instance = SyncService._();
  factory SyncService() => _instance;
  SyncService._();

  static const _api = CloudApi();
  static const _transactions = TransactionRepository();
  static const _products = ProductRepository();

  static const _keyCursor = 'sync_pull_cursor';

  /// Kursor versi lama, waktu yang ditarik hanya penukaran. Tidak dipakai lagi,
  /// tapi tetap dibuang di [reset] supaya tidak tertinggal milik akun lain.
  static const _keyLegacyCursor = 'sync_redemption_cursor';

  /// Matches the server's `max:500` cap with room to spare.
  static const _batchSize = 200;

  /// How often the background loop runs.
  ///
  /// Bukan realtime dan tidak perlu: yang ditunggu hanyalah kabar tiket sudah
  /// ditukar dari perangkat lain. 15 detik terasa cukup cepat tanpa membuat
  /// perangkat mengetuk server ribuan kali sehari. Setel di sini kalau perlu.
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
      if (await push() case Err(:final error)) {
        AppLog.error('Sync push gagal: $error');
      }
      if (await pull() case Err(:final error)) {
        AppLog.error('Sync pull gagal: $error');
      }
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
          // daftar pendek yang tidak berubah antar batch.
          final products = round == 0
              ? (await _products.all()).valueOrNull ?? const <Product>[]
              : const <Product>[];
          final deleted = round == 0
              ? (await _transactions.pendingDeletes()).valueOrNull ??
                    const <String>[]
              : const <String>[];

          switch (await _api.push(
            pending,
            products: products,
            deleted: deleted,
          )) {
            case Err(:final message, :final error, :final stackTrace):
              return Err(message, error, stackTrace);
            case Ok():
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

  /// Brings down everything this device hasn't seen: tickets another till sold,
  /// and tickets the verifier redeemed.
  ///
  /// Pulling whole rows and not just redemptions is what makes two tills — or a
  /// till and a verifier — show the same history. Which of the two rules applies
  /// to each row is [TransactionRepository.applyRemote]'s call, not ours.
  Future<Result<int>> pull() async {
    final prefs = await SharedPreferences.getInstance();

    final result = await _api.pull(since: prefs.getString(_keyCursor));
    switch (result) {
      case Err(:final message, :final error, :final stackTrace):
        return Err(message, error, stackTrace);
      case Ok(value: final page):
        final applied = await _transactions.applyRemote(
          page.transactions,
          page.items,
        );
        if (applied case Err(:final message, :final error, :final stackTrace)) {
          return Err(message, error, stackTrace);
        }

        // Katalog ikut turun supaya kasir kedua tidak perlu mengetik ulang
        // paketnya. Kegagalannya tidak membatalkan kursor — produk akan ikut
        // lagi di poll berikutnya, transaksi tidak.
        if (await _products.upsertAll(page.products) case Err(:final error)) {
          AppLog.error('Gagal menyalin produk dari server: $error');
        }

        // Kursor disimpan hanya setelah baris benar-benar tertulis. Kalau
        // urutannya dibalik, satu kegagalan tulis membuat baris itu terlewat
        // selamanya.
        final cursor = page.cursor;
        if (cursor != null) await prefs.setString(_keyCursor, cursor);

        final changed = applied.valueOrNull ?? 0;
        if (changed > 0) dataRefresh.invalidate();
        return Ok(changed);
    }
  }

  /// Cursor must be dropped along with the account — the next login may be a
  /// different one, whose rows all predate this cursor.
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCursor);
    await prefs.remove(_keyLegacyCursor);
    AppLog.info('Sync cursor direset');
  }
}
