import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luminara_photobooth/core/blocs/async_state.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/core/services/server_service.dart';

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

  const TransactionHistoryState({
    this.transactions = const AsyncLoading(),
    required this.filter,
  });

  List<Transaction> get items =>
      transactions.dataOrNull ?? const <Transaction>[];

  /// Derived rather than stored — the old screen kept a `_totalIncome` field
  /// that had to be recomputed by hand on every list change.
  int get totalIncome => items.fold(0, (sum, t) => sum + t.totalPrice);

  TransactionHistoryState copyWith({
    AsyncState<List<Transaction>>? transactions,
    DateRangeFilter? filter,
  }) => TransactionHistoryState(
    transactions: transactions ?? this.transactions,
    filter: filter ?? this.filter,
  );

  @override
  List<Object?> get props => [transactions, filter];
}

class TransactionHistoryCubit extends Cubit<TransactionHistoryState> {
  TransactionHistoryCubit({
    TransactionRepository repository = const TransactionRepository(),
  }) : _repository = repository,
       super(TransactionHistoryState(filter: DateRangeFilter.today)) {
    // The verifier redeeming a ticket changes a row we may be displaying.
    _serverEvents = ServerService().appEventStream.listen((event) {
      if (event == 'REFRESH_TRANSACTIONS') load();
    });
    dataRefresh.addListener(load);
  }

  final TransactionRepository _repository;
  late final StreamSubscription<String> _serverEvents;

  Future<void> load() async {
    emit(
      state.copyWith(transactions: AsyncLoading(state.transactions.dataOrNull)),
    );

    final range = state.filter.range;
    final result = range == null
        ? await _repository.all()
        : await _repository.byDateRange(range.start, range.end);

    if (!isClosed) emit(state.copyWith(transactions: result.toAsyncState()));
  }

  Future<void> applyFilter(DateRangeFilter filter) async {
    emit(state.copyWith(filter: filter));
    await load();
  }

  /// Returns null on success, or a message to show the user.
  Future<String?> delete(Transaction transaction) async {
    if (await _repository.delete(transaction.uuid) case Err(:final message)) {
      return message;
    }
    await load();
    return null;
  }

  @override
  Future<void> close() {
    _serverEvents.cancel();
    dataRefresh.removeListener(load);
    return super.close();
  }
}
