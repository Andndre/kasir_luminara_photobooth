import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/model/transaksi.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

part 'sections/item_section.dart';

class TransactionPage extends StatefulWidget {
  const TransactionPage({super.key});

  @override
  State<TransactionPage> createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  List<Transaksi> _transactions = [];
  bool _isLoading = true;
  
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
        _totalIncome = transactions.fold(0, (sum, item) => sum + item.productPrice);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        SnackBarHelper.showError(context, 'Error loading transactions: $e');
      }
    }
  }

  void _applyFilter(String label, DateTimeRange range) {
    setState(() {
      _filterLabel = label;
      _selectedDateRange = range;
    });
    _loadTransactions();
  }

  Future<void> _showMonthPicker() async {
    try {
      final months = await Transaksi.getAvailableTransactionMonths();
      
      if (!mounted) return;

      if (months.isEmpty) {
        SnackBarHelper.showWarning(context, 'Belum ada data transaksi.');
        return;
      }

      await showModalBottomSheet(
        context: context,
        builder: (context) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Pilih Bulan Laporan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: months.length,
                  itemBuilder: (context, index) {
                    final date = months[index];
                    final label = DateFormat('MMMM yyyy', 'id_ID').format(date);
                    
                    return ListTile(
                      title: Text(label, textAlign: TextAlign.center),
                      onTap: () {
                        // Create range for full month
                        final start = DateTime(date.year, date.month, 1);
                        final end = DateTime(date.year, date.month + 1, 0);
                        
                        _applyFilter(label, DateTimeRange(start: start, end: end));
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      );
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Gagal memuat data bulan: $e');
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
            icon: const Icon(Icons.refresh),
            onPressed: _loadTransactions,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
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
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadTransactions,
                        child: isDesktop
                            ? GridView.builder(
                                padding: const EdgeInsets.all(16),
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 400,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  mainAxisExtent: 130,
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
                                padding: const EdgeInsets.all(8),
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
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.blue[800]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(Dimens.radius),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monetization_on_outlined, color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                'Total Pemasukan ($_filterLabel)',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            currencyFormatter.format(_totalIncome),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterHeader(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip('Hari Ini', () {
            final now = DateTime.now();
            _applyFilter('Hari Ini', DateTimeRange(start: now, end: now));
          }),
          const SizedBox(width: 8),
          _buildFilterChip('Kemarin', () {
            final yesterday = DateTime.now().subtract(const Duration(days: 1));
            _applyFilter('Kemarin', DateTimeRange(start: yesterday, end: yesterday));
          }),
          const SizedBox(width: 8),
          _buildFilterChip('Bulan Ini', () {
            final now = DateTime.now();
            final start = DateTime(now.year, now.month, 1);
            final end = DateTime(now.year, now.month + 1, 0);
            _applyFilter('Bulan Ini', DateTimeRange(start: start, end: end));
          }),
          const SizedBox(width: 8),
          ActionChip(
            avatar: const Icon(Icons.calendar_view_month, size: 16),
            label: const Text('Pilih Bulan'),
            onPressed: _showMonthPicker,
            backgroundColor: theme.cardTheme.color,
            side: BorderSide(color: theme.dividerTheme.color ?? Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onTap) {
    final isSelected = _filterLabel == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : null,
        fontWeight: isSelected ? FontWeight.bold : null,
      ),
      side: isSelected ? const BorderSide(color: AppColors.primary) : null,
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
      // Logic for delete is missing in current model, adding it to model if needed or skip
      // For now, we focus on the core flow.
    }
  }
}