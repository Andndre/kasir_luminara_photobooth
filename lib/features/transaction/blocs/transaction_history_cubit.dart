import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luminara_photobooth/core/blocs/async_state.dart';
import 'package:luminara_photobooth/core/core.dart';

/// A named period shown as a pill in the filter track. A null [range] means
/// "everything".
class DateRangeFilter extends Equatable {
  final String label;
  final DateTimeRange? range;

  const DateRangeFilter(this.label, this.range);

  static DateRangeFilter get today {
    final now = DateTime.now();
    return DateRangeFilter('Hari Ini', DateTimeRange(start: now, end: now));
  }

  static DateRangeFilter get yesterday {
    final day = DateTime.now().subtract(const Duration(days: 1));
    return DateRangeFilter('Kemarin', DateTimeRange(start: day, end: day));
  }

  static DateRangeFilter get thisMonth {
    final now = DateTime.now();
    return DateRangeFilter(
      'Bulan Ini',
      DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        // Day 0 of next month is the last day of this one.
        end: DateTime(now.year, now.month + 1, 0),
      ),
    );
  }

  static const all = DateRangeFilter('Semua Data', null);

  /// The presets shown in the filter track, rebuilt each call so "Hari Ini"
  /// stays correct if the app is left open past midnight.
  static List<DateRangeFilter> presets() => [all, today, yesterday, thisMonth];

  @override
  List<Object?> get props => [label, range];
}

class TransactionHistoryState extends Equatable {
  final AsyncState<List<Transaction>> transactions;
  final DateRangeFilter filter;

  /// Server tidak terjawab, jadi yang tampil adalah salinan lokal perangkat
  /// ini — hanya transaksi buatannya sendiri. Layar wajib menyatakannya:
  /// riwayat sebagian yang terlihat seperti riwayat lengkap adalah laporan
  /// pendapatan yang salah, dan angkanya dipakai menghitung uang.
  final bool offline;

  const TransactionHistoryState({
    this.transactions = const AsyncLoading(),
    required this.filter,
    this.offline = false,
  });

  List<Transaction> get items =>
      transactions.dataOrNull ?? const <Transaction>[];

  /// Derived rather than stored — the old screen kept a `_totalIncome` field
  /// that had to be recomputed by hand on every list change.
  int get totalIncome => items.fold(0, (sum, t) => sum + t.totalPrice);

  TransactionHistoryState copyWith({
    AsyncState<List<Transaction>>? transactions,
    DateRangeFilter? filter,
    bool? offline,
  }) => TransactionHistoryState(
    transactions: transactions ?? this.transactions,
    filter: filter ?? this.filter,
    offline: offline ?? this.offline,
  );

  @override
  List<Object?> get props => [transactions, filter, offline];
}

/// Satu halaman riwayat, beserta kabar apakah server yang menjawabnya.
typedef HistoryPage = ({List<Transaction> rows, bool offline});

/// Dari mana satu halaman riwayat diambil. `null` berarti semua tanggal.
///
/// Ada supaya kasir dan verifier bisa memakai layar yang sama persis dengan
/// sumber yang berbeda — keduanya sekarang dari server, tapi kasir menambahkan
/// baris yang belum sempat naik dan punya jalan mundur ke salinan lokal.
/// Sengaja sebuah fungsi dan bukan antarmuka dengan dua implementasi: yang
/// berbeda cuma satu panggilan, bukan sebuah peran.
typedef HistoryLoader =
    Future<Result<HistoryPage>> Function(DateTimeRange? range);

class TransactionHistoryCubit extends Cubit<TransactionHistoryState> {
  TransactionHistoryCubit({required HistoryLoader loader})
    : _load = loader,
      super(TransactionHistoryState(filter: DateRangeFilter.today)) {
    // Dipicu saat seluruh database diganti (restore) atau saat perangkat ini
    // mengambil peran kasir. Bukan timer: tidak ada yang memuat ulang layar ini
    // sendiri, dan itu disengaja — lihat tombol segarkan di AppBar.
    dataRefresh.addListener(load);
  }

  final HistoryLoader _load;

  /// Bumped per load. A filter change or a server event can start a second
  /// query while the first is still running; without this the slower one wins.
  var _generation = 0;

  Future<void> load() async {
    if (isClosed) return;
    final generation = ++_generation;

    emit(
      state.copyWith(transactions: AsyncLoading(state.transactions.dataOrNull)),
    );

    final result = await _load(state.filter.range);

    if (isClosed || generation != _generation) return;
    emit(
      state.copyWith(
        transactions: switch (result) {
          Ok(:final value) => AsyncReady(value.rows),
          Err(:final message) => AsyncFailed(message),
        },
        // Gagal total bukan "offline" — layarnya sudah menampilkan pesan
        // kesalahan, dan bilah kedua yang mengulanginya cuma bising.
        offline: result.valueOrNull?.offline ?? false,
      ),
    );
  }

  Future<void> applyFilter(DateRangeFilter filter) async {
    emit(state.copyWith(filter: filter));
    await load();
  }

  /// Returns null on success, or a message to show the user.
  ///
  /// Selalu ke SQLite lokal, tidak lewat [HistoryLoader]: menghapus adalah
  /// tindakan sisi pembuat, dan yang membuat cuma kasir. Verifier tidak pernah
  /// sampai ke sini karena tombolnya memang tidak ditampilkan di sana.
  Future<String?> delete(Transaction transaction) async {
    const repository = TransactionRepository();
    if (await repository.delete(transaction.uuid) case Err(:final message)) {
      return message;
    }
    await load();
    return null;
  }

  @override
  Future<void> close() {
    dataRefresh.removeListener(load);
    return super.close();
  }
}
