import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:luminara_photobooth/core/blocs/async_state.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/features/transaction/blocs/transaction_history_cubit.dart';
import 'package:luminara_photobooth/features/transaction/services/transaction_export.dart';
import 'package:luminara_photobooth/features/transaction/widgets/transaction_card.dart';
import 'package:luminara_photobooth/features/transaction/widgets/transaction_detail_dialog.dart';

/// Jepit rentang ke [firstDate]–[lastDate] sebelum diberikan ke
/// `showDateRangePicker`.
///
/// Tanpa ini picker gagal terbuka lewat assertion: filter "Bulan Ini" memakai
/// akhir bulan yang masih di masa depan, sementara `lastDate` dipatok hari ini.
@visibleForTesting
DateTimeRange? clampRange(
  DateTimeRange? range,
  DateTime firstDate,
  DateTime lastDate,
) {
  if (range == null) return null;

  var start = range.start.isBefore(firstDate) ? firstDate : range.start;
  var end = range.end.isAfter(lastDate) ? lastDate : range.end;

  if (start.isAfter(lastDate)) start = lastDate;
  if (end.isBefore(firstDate)) end = firstDate;
  if (end.isBefore(start)) end = start;

  return DateTimeRange(start: start, end: end);
}

class TransactionPage extends StatelessWidget {
  const TransactionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TransactionHistoryCubit()..load(),
      child: const _TransactionView(),
    );
  }
}

class _TransactionView extends StatelessWidget {
  const _TransactionView();

  Future<void> _export(BuildContext context) async {
    final transactions = context.read<TransactionHistoryCubit>().state.items;
    if (transactions.isEmpty) {
      SnackBarHelper.showWarning(context, 'Tidak ada data untuk diexport');
      return;
    }

    final result = await TransactionExport.toExcel(transactions);
    if (!context.mounted) return;

    result.fold(
      ok: (path) =>
          SnackBarHelper.showSuccess(context, 'File disimpan di: $path'),
      err: (message, _) {
        AppLog.error(message);
        SnackBarHelper.showError(context, message);
      },
    );
  }

  Future<void> _openDetail(
    BuildContext context,
    Transaction transaction,
  ) async {
    final cubit = context.read<TransactionHistoryCubit>();
    final action = await TransactionDetailDialog.show(context, transaction);
    if (action != TransactionDetailAction.delete || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Transaksi'),
        content: Text('Yakin ingin menghapus transaksi ${transaction.uuid}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTokens.danger),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final error = await cubit.delete(transaction);
    if (!context.mounted) return;

    if (error != null) {
      AppLog.error(error);
      SnackBarHelper.showError(context, error);
    } else {
      SnackBarHelper.showSuccess(context, 'Transaksi berhasil dihapus');
    }
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final cubit = context.read<TransactionHistoryCubit>();
    final firstDate = DateTime(2020);
    final lastDate = DateTime.now();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: clampRange(
        cubit.state.filter.range,
        firstDate,
        lastDate,
      ),
      helpText: 'Pilih Rentang Tanggal',
      confirmText: 'Pilih',
      cancelText: 'Batal',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AppColors.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (picked == null) return;

    final formatter = DateFormat('dd MMM yyyy', 'id_ID');
    await cubit.applyFilter(
      DateRangeFilter(
        '${formatter.format(picked.start)} - ${formatter.format(picked.end)}',
        picked,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        foregroundColor: theme.appBarTheme.foregroundColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export Excel',
            onPressed: () => _export(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: context.read<TransactionHistoryCubit>().load,
          ),
          const SizedBox(width: Dimens.dp8),
        ],
      ),
      body: SafeArea(
        child: BlocBuilder<TransactionHistoryCubit, TransactionHistoryState>(
          builder: (context, state) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Dimens.dp16,
                  Dimens.dp8,
                  Dimens.dp16,
                  Dimens.dp16,
                ),
                child: HeroPanel(
                  label: 'Total Pemasukan · ${state.filter.label}',
                  value: Currency.format(state.totalIncome),
                  meta: '${state.items.length} transaksi',
                ),
              ),
              _FilterTrack(
                selected: state.filter,
                onSelect: context.read<TransactionHistoryCubit>().applyFilter,
                onPickRange: () => _pickDateRange(context),
              ),
              Expanded(
                child: switch (state.transactions) {
                  AsyncLoading(previous: null) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  AsyncFailed(:final message) => EmptyState(
                    isError: true,
                    icon: Icons.receipt_long_outlined,
                    title: 'Gagal memuat transaksi',
                    message: message,
                    actionLabel: 'Coba Lagi',
                    onAction: context.read<TransactionHistoryCubit>().load,
                  ),
                  _ when state.items.isEmpty => EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Belum ada transaksi',
                    message:
                        'Tidak ada penjualan pada periode ${state.filter.label}.',
                  ),
                  _ => _HistoryList(
                    transactions: state.items,
                    isDesktop: isDesktop,
                    onTap: (t) => _openDetail(context, t),
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.transactions,
    required this.isDesktop,
    required this.onTap,
  });

  final List<Transaction> transactions;
  final bool isDesktop;
  final void Function(Transaction) onTap;

  static const _padding = EdgeInsets.fromLTRB(
    Dimens.dp16,
    Dimens.dp16,
    Dimens.dp16,
    Dimens.dp8,
  );

  @override
  Widget build(BuildContext context) {
    Widget cardAt(int index) => TransactionCard(
      transaction: transactions[index],
      onTap: () => onTap(transactions[index]),
    );

    return RefreshIndicator(
      onRefresh: context.read<TransactionHistoryCubit>().load,
      child: isDesktop
          ? GridView.builder(
              padding: _padding,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 420,
                crossAxisSpacing: Dimens.dp12,
                mainAxisSpacing: 0,
                mainAxisExtent: 126,
              ),
              itemCount: transactions.length,
              itemBuilder: (_, index) => cardAt(index),
            )
          : ListView.builder(
              padding: _padding,
              itemCount: transactions.length,
              itemBuilder: (_, index) => cardAt(index),
            ),
    );
  }
}

class _FilterTrack extends StatelessWidget {
  const _FilterTrack({
    required this.selected,
    required this.onSelect,
    required this.onPickRange,
  });

  final DateRangeFilter selected;
  final void Function(DateRangeFilter) onSelect;
  final VoidCallback onPickRange;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Dimens.dp16),
      child: Row(
        children: [
          // Track tersegmen: satu wadah, item aktif jadi pil terangkat.
          Container(
            padding: const EdgeInsets.all(Dimens.dp4),
            decoration: BoxDecoration(
              color: surfaces.surfaceAlt,
              borderRadius: BorderRadius.circular(Dimens.rFull),
            ),
            child: Row(
              children: [
                for (final filter in DateRangeFilter.presets())
                  _FilterPill(
                    label: filter.label,
                    selected: selected.label == filter.label,
                    onTap: () => onSelect(filter),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Dimens.dp8),
          IconButton(
            onPressed: onPickRange,
            tooltip: 'Rentang Tanggal',
            icon: const Icon(Icons.date_range_rounded, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: surfaces.surfaceAlt,
              minimumSize: const Size(44, 44),
            ),
          ),
        ],
      ),
    );
  }
}

/// Item di dalam track filter. Aktif = pil ivory terangkat di atas track.
class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Dimens.rFull),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(
            horizontal: Dimens.dp16,
            vertical: Dimens.dp10,
          ),
          decoration: BoxDecoration(
            // JANGAN Colors.transparent: itu HITAM dengan alpha 0, jadi lerp
            // ivory → transparan melewati hitam semi-transparan dan berkedip
            // gelap. Fade ke warna yang sama, cuma alpha-nya yang turun.
            color: theme.colorScheme.surface.withValues(
              alpha: selected ? 1 : 0,
            ),
            borderRadius: BorderRadius.circular(Dimens.rFull),
            // Alasan yang sama seperti warna di atas: lerp ke list kosong
            // memakai BoxShadow default (hitam, blur 0), jadi pil yang baru
            // dilepas meninggalkan jejak gelap. Turunkan alpha-nya saja.
            boxShadow: [
              for (final shadow in surfaces.cardShadow)
                selected
                    ? shadow
                    : shadow.copyWith(color: shadow.color.withValues(alpha: 0)),
            ],
          ),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: selected
                  ? theme.colorScheme.primary
                  : surfaces.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
