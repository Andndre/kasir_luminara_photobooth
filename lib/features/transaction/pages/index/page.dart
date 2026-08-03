import 'dart:async';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:luminara_photobooth/model/log.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/core/preferences/app_state.dart';
import 'package:luminara_photobooth/core/services/server_service.dart';
import 'package:luminara_photobooth/model/transaksi.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';

part 'sections/item_section.dart';

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

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
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
          color: theme.colorScheme.surface.withValues(alpha: selected ? 1 : 0),
          borderRadius: BorderRadius.circular(Dimens.rFull),
          boxShadow: selected ? surfaces.cardShadow : const [],
        ),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: selected ? theme.colorScheme.primary : surfaces.textSecondary,
          ),
        ),
      ),
    );
  }
}

class TransactionPage extends StatefulWidget {
  const TransactionPage({super.key});

  @override
  State<TransactionPage> createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  List<Transaksi> _transactions = [];
  bool _isLoading = true;
  StreamSubscription<String>? _eventSubscription;

  // Filter State
  DateTimeRange? _selectedDateRange;
  String _filterLabel = 'Hari Ini';
  int _totalIncome = 0;

  @override
  void initState() {
    super.initState();
    // Default filter: Hari Ini
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(start: now, end: now);
    _loadTransactions();

    _eventSubscription = ServerService().appEventStream.listen((event) {
      if (event == 'REFRESH_TRANSACTIONS') {
        _loadTransactions();
      }
    });

    // Listen untuk refresh setelah restore
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      appState.addListener(_onAppStateChanged);
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    // Cleanup listener
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AppState>().removeListener(_onAppStateChanged);
      }
    });
    super.dispose();
  }

  void _onAppStateChanged() {
    // Refresh transactions saat AppState memberi signal
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<Transaksi> transactions;
      if (_selectedDateRange != null) {
        transactions = await Transaksi.getTransactionsByDateRange(
          _selectedDateRange!.start,
          _selectedDateRange!.end,
        );
      } else {
        transactions = await Transaksi.getAllTransaksi();
      }

      setState(() {
        _transactions = transactions;
        _totalIncome = transactions.fold(
          0,
          (sum, item) => sum + item.totalPrice,
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        Log.insertLog('Error loading transactions: $e', isError: true);
        SnackBarHelper.showError(context, 'Error loading transactions: $e');
      }
    }
  }

  void _applyFilter(String label, DateTimeRange? range) {
    setState(() {
      _filterLabel = label;
      _selectedDateRange = range;
    });
    _loadTransactions();
  }

  Future<void> _showDateRangePicker() async {
    try {
      final firstDate = DateTime(2020);
      final lastDate = DateTime.now();

      // Gunakan DatePicker untuk memilih rentang tanggal
      final DateTimeRange? picked = await showDateRangePicker(
        context: context,
        firstDate: firstDate,
        lastDate: lastDate,
        initialDateRange: clampRange(_selectedDateRange, firstDate, lastDate),
        helpText: 'Pilih Rentang Tanggal',
        confirmText: 'Pilih',
        cancelText: 'Batal',
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                  ),
            ),
            child: child!,
          );
        },
      );

      if (picked != null) {
        // Format label untuk display
        final dateFormatter = DateFormat('dd MMM yyyy', 'id_ID');
        final label =
            '${dateFormatter.format(picked.start)} - ${dateFormatter.format(picked.end)}';

        _applyFilter(label, picked);
      }
    } catch (e) {
      if (mounted) {
        Log.insertLog('Gagal membuka date picker: $e', isError: true);
        SnackBarHelper.showError(context, 'Gagal membuka date picker: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
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
            onPressed: _exportToExcel,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTransactions,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSummaryCard(theme),
            _buildFilterHeader(theme),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _transactions.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Belum ada transaksi',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadTransactions,
                      child: isDesktop
                          ? GridView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 420,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 0,
                                    mainAxisExtent: 126,
                                  ),
                              itemCount: _transactions.length,
                              itemBuilder: (context, index) {
                                final transaction = _transactions[index];
                                return _ItemSection(
                                  transaksi: transaction,
                                  onDelete: () =>
                                      _deleteTransaction(transaction),
                                );
                              },
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              itemCount: _transactions.length,
                              itemBuilder: (context, index) {
                                final transaction = _transactions[index];
                                return _ItemSection(
                                  transaksi: transaction,
                                  onDelete: () =>
                                      _deleteTransaction(transaction),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportToExcel() async {
    if (_transactions.isEmpty) {
      SnackBarHelper.showWarning(context, 'Tidak ada data untuk diexport');
      return;
    }

    try {
      final excel = Excel.createExcel();
      final sheet = excel['Laporan'];

      // Headers
      sheet.appendRow([
        TextCellValue('UUID'),
        TextCellValue('Tanggal'),
        TextCellValue('Jam'),
        TextCellValue('Pelanggan'),
        TextCellValue('Rincian Produk'),
        TextCellValue('Harga Total'),
        TextCellValue('Metode'),
        TextCellValue('Status'),
        TextCellValue('Waktu Redeem'),
      ]);

      final dateFormatter = DateFormat('yyyy-MM-dd');
      final timeFormatter = DateFormat('HH:mm:ss');

      // Data Rows
      for (var t in _transactions) {
        final itemsSummary = t.items
            .map((i) => '${i.productName} (x${i.quantity})')
            .join(', ');

        sheet.appendRow([
          TextCellValue(t.uuid),
          TextCellValue(dateFormatter.format(t.createdAt)),
          TextCellValue(timeFormatter.format(t.createdAt)),
          TextCellValue(t.customerName ?? '-'),
          TextCellValue(itemsSummary),
          IntCellValue(t.totalPrice),
          TextCellValue(t.paymentMethod),
          TextCellValue(t.status),
          TextCellValue(
            t.redeemedAt != null
                ? '${dateFormatter.format(t.redeemedAt!)} ${timeFormatter.format(t.redeemedAt!)}'
                : '-',
          ),
        ]);
      }

      // Save File
      Directory? directory;
      if (Platform.isAndroid || Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getDownloadsDirectory();
      }

      if (directory != null) {
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final fileName = 'Laporan_Luminara_$timestamp.xlsx';
        final path = '${directory.path}/$fileName';

        File(path)
          ..createSync(recursive: true)
          ..writeAsBytesSync(excel.save()!);

        if (mounted) {
          SnackBarHelper.showSuccess(context, 'File disimpan di: $path');
        }
      }
    } catch (e) {
      if (mounted) {
        Log.insertLog('Gagal export data: $e', isError: true);
        SnackBarHelper.showError(context, 'Gagal export data: $e');
      }
    }
  }

  Widget _buildSummaryCard(ThemeData theme) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimens.dp16,
        Dimens.dp8,
        Dimens.dp16,
        Dimens.dp16,
      ),
      child: HeroPanel(
        label: 'Total Pemasukan · $_filterLabel',
        value: currencyFormatter.format(_totalIncome),
        meta: '${_transactions.length} transaksi',
      ),
    );
  }

  Widget _buildFilterHeader(ThemeData theme) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    final filters = <(String, DateTimeRange?)>[
      ('Semua Data', null),
      ('Hari Ini', DateTimeRange(start: now, end: now)),
      ('Kemarin', DateTimeRange(start: yesterday, end: yesterday)),
      (
        'Bulan Ini',
        DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0),
        ),
      ),
    ];

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
                for (final (label, range) in filters)
                  _FilterPill(
                    label: label,
                    selected: _filterLabel == label,
                    onTap: () => _applyFilter(label, range),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Dimens.dp8),
          IconButton(
            onPressed: _showDateRangePicker,
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

  Future<void> _deleteTransaction(Transaksi transaksi) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Transaksi'),
        content: Text('Yakin ingin menghapus transaksi ${transaksi.uuid}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await Transaksi.deleteTransaksi(transaksi.uuid);
        if (mounted) {
          SnackBarHelper.showSuccess(context, 'Transaksi berhasil dihapus');
          _loadTransactions();
        }
      } catch (e) {
        if (mounted) {
          Log.insertLog('Gagal menghapus transaksi: $e', isError: true);
          SnackBarHelper.showError(context, 'Gagal menghapus transaksi: $e');
        }
      }
    }
  }
}
