import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:luminara_photobooth/core/blocs/async_state.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/core/services/cloud_api.dart';
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
      create: (_) =>
          TransactionHistoryCubit(loader: TransactionHistoryView.forCashier)
            ..load(),
      child: const _TransactionView(),
    );
  }
}

/// Riwayat tanpa Scaffold, supaya bisa dipasang sebagai tab. Verifier
/// memakainya di samping antrean; kasir memakai [TransactionPage] yang
/// membungkusnya dengan AppBar dan tombol export.
class TransactionHistoryView extends StatelessWidget {
  const TransactionHistoryView({
    super.key,
    required this.loader,
    this.canDelete = true,
  });

  /// Dari mana barisnya diambil. Wajib diisi: dulu bawaannya SQLite lokal, dan
  /// bawaan diam-diam itulah yang membuat riwayat kasir berbeda antar perangkat
  /// tanpa ada yang menyadarinya.
  final HistoryLoader loader;

  /// Verifier membaca saja — lihat [TransactionDetailDialog.canDelete].
  final bool canDelete;

  /// Riwayat yang dibaca langsung dari luminarabali.com.
  ///
  /// Batas atas dikirim sebagai hari BERIKUTNYA karena server
  /// membandingkannya secara eksklusif; menambal "23:59:59" akan memotong
  /// transaksi yang detiknya berpecahan.
  ///
  /// Dipakai verifier, yang tidak menyimpan salinan lokal apa pun — kalau
  /// server tidak terjawab, tidak ada yang bisa ditampilkan, dan mengarang
  /// jalan mundur di sini justru menyembunyikan itu.
  static Future<Result<HistoryPage>> fromServer(DateTimeRange? range) async =>
      switch (await _serverRows(range)) {
        Ok(:final value) => Ok((rows: value, offline: false)),
        Err(:final message, :final error, :final stackTrace) => Err(
          message,
          error,
          stackTrace,
        ),
      };

  /// Riwayat kasir: server sebagai sumber, salinan lokal sebagai jaring.
  ///
  /// Server yang menjawab, bukan SQLite, supaya riwayat tidak lagi berbeda
  /// antar perangkat setelah peran kasir berpindah — server memegang semuanya,
  /// tiap perangkat cuma memegang buatannya sendiri.
  ///
  /// Dua hal yang membuatnya tidak sesederhana [fromServer]:
  ///
  /// - Baris yang belum sempat naik belum ada di jawaban server. Tanpa
  ///   digabungkan, penjualan yang baru saja dibuat saat internet putus hilang
  ///   dari riwayat kasirnya sendiri — uang yang sudah diterima tapi tidak
  ///   terlihat, yang lebih buruk daripada masalah yang layar ini perbaiki.
  /// - Server tidak terjawab bukan alasan mengosongkan layar. Jatuh ke salinan
  ///   lokal, tapi TANDAI: itu riwayat sebagian.
  static Future<Result<HistoryPage>> forCashier(DateTimeRange? range) async {
    const repository = TransactionRepository();

    switch (await _serverRows(range)) {
      case Ok(value: final remote):
        final pending = (await repository.unsynced()).valueOrNull ?? const [];
        return Ok((rows: mergePending(remote, pending, range), offline: false));

      case Err(:final message, :final error, :final stackTrace):
        AppLog.error('Riwayat dari server gagal, pakai salinan lokal: $error');
        return switch (await _localRows(range)) {
          Ok(value: final rows) => Ok((rows: rows, offline: true)),
          // Lokal ikut gagal: tidak ada apa pun untuk ditampilkan, jadi
          // kegagalan server yang dilaporkan — itu sebab yang sebenarnya.
          Err() => Err(message, error, stackTrace),
        };
    }
  }

  /// Menyisipkan baris yang belum sampai server ke dalam jawaban server.
  ///
  /// Uuid yang sudah ada di [remote] menang: barisnya sudah mendarat, dan
  /// salinan lokalnya bisa lebih tua — status penukaran misalnya, yang
  /// ditentukan server dan tidak pernah ikut naik.
  @visibleForTesting
  static List<Transaction> mergePending(
    List<Transaction> remote,
    List<Transaction> pending,
    DateTimeRange? range,
  ) {
    final seen = remote.map((t) => t.uuid).toSet();
    return [
      ...remote,
      ...pending.where(
        (t) => !seen.contains(t.uuid) && _inRange(t.createdAt, range),
      ),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Future<Result<List<Transaction>>> _serverRows(DateTimeRange? range) =>
      const CloudApi().history(
        from: range == null ? null : _isoDate(range.start),
        to: range == null
            ? null
            : _isoDate(range.end.add(const Duration(days: 1))),
      );

  static Future<Result<List<Transaction>>> _localRows(DateTimeRange? range) {
    const repository = TransactionRepository();
    return range == null
        ? repository.all()
        : repository.byDateRange(range.start, range.end);
  }

  /// Rentangnya inklusif di kedua ujung, dibandingkan per hari — sama seperti
  /// yang dikirim ke server, supaya baris tertunda tidak muncul di filter yang
  /// seharusnya tidak memuatnya.
  static bool _inRange(DateTime at, DateTimeRange? range) {
    if (range == null) return true;
    final day = DateTime(at.year, at.month, at.day);
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(range.end.year, range.end.month, range.end.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  static String _isoDate(DateTime value) => DateTime(
    value.year,
    value.month,
    value.day,
  ).toIso8601String().substring(0, 10);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TransactionHistoryCubit(loader: loader)..load(),
      child: _HistoryBody(canDelete: canDelete),
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

    switch (result) {
      case Ok(:final value):
        SnackBarHelper.showSuccess(context, 'File disimpan di: $value');
      // Menutup dialog simpan adalah keluar biasa, bukan kegagalan.
      case Err(error: ExportCancelled()):
        break;
      case Err(:final message):
        AppLog.error(message);
        SnackBarHelper.showError(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
      body: const SafeArea(child: _HistoryBody()),
    );
  }
}

/// Menyatakan bahwa yang tampil bukan riwayat akun, melainkan salinan lokal.
///
/// Prinsipnya sama dengan CashierLeaseBanner dan _FreshnessBar: keadaan yang
/// tidak bisa dijamin tidak boleh terlihat seperti yang bisa. Di layar ini
/// taruhannya paling tinggi — angka "Total Pemasukan" di atasnya dipakai
/// menghitung uang, dan riwayat sebagian menghasilkan total yang salah tanpa
/// terlihat salah.
class _OfflineHistoryBar extends StatelessWidget {
  const _OfflineHistoryBar();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(
      horizontal: Dimens.dp16,
      vertical: Dimens.dp8,
    ),
    color: AppTokens.warning.withValues(alpha: 0.15),
    child: Row(
      children: [
        const Icon(Icons.cloud_off_rounded, size: 16, color: AppTokens.warning),
        const SizedBox(width: Dimens.dp8),
        Expanded(
          child: Text(
            'Server tidak terjawab — menampilkan salinan perangkat ini saja, '
            'tanpa transaksi dari perangkat lain.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTokens.warning),
          ),
        ),
      ],
    ),
  );
}

/// Panel ringkasan + track filter + daftar. Dipakai kasir dan verifier.
class _HistoryBody extends StatelessWidget {
  const _HistoryBody({this.canDelete = true});

  final bool canDelete;

  Future<void> _openDetail(
    BuildContext context,
    Transaction transaction,
  ) async {
    final cubit = context.read<TransactionHistoryCubit>();
    final action = await TransactionDetailDialog.show(
      context,
      transaction,
      canDelete: canDelete,
    );
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
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return BlocBuilder<TransactionHistoryCubit, TransactionHistoryState>(
      builder: (context, state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.offline) const _OfflineHistoryBar(),
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
