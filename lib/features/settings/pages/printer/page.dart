import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/core/preferences/printer_preferences.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

class PrinterPage extends StatefulWidget {
  final bool isFromTransaction;

  const PrinterPage({super.key, this.isFromTransaction = false});

  @override
  State<PrinterPage> createState() => _PrinterPageState();
}

class _PrinterPageState extends State<PrinterPage> {
  List<BluetoothInfo> _devices = [];
  final Map<String, bool> _paperMm80 = {};
  bool _isScanning = false;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _checkConnectionStatus();
    _loadPairedDevices();
  }

  Future<void> _checkConnectionStatus() async {
    final connected = await PrinterHelper.isConnected;
    setState(() => _isConnected = connected);
  }

  Future<void> _loadPairedDevices() async {
    setState(() => _isScanning = true);
    try {
      final devices = await PrinterHelper.getPairedDevices();

      final paperSizes = <String, bool>{};
      for (final device in devices) {
        paperSizes[device.macAdress] = await PrinterPreferences.isPaperMm80(
          device.macAdress,
        );
      }

      setState(() {
        _devices = devices;
        _paperMm80
          ..clear()
          ..addAll(paperSizes);
      });
    } catch (e) {
      if (mounted) {
        AppLog.error('Error loading paired devices: $e');
        SnackBarHelper.showError(context, 'Error loading paired devices: $e');
      }
    } finally {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _connectToPrinter(BluetoothInfo device) async {
    try {
      _showLoading('Connecting to ${device.name}...');

      final success = await PrinterHelper.connect(device.macAdress);

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (success) {
        setState(() {
          _isConnected = true;
          PrinterHelper.connectedPrinterName = device.name;
        });
        SnackBarHelper.showSuccess(context, 'Connected to ${device.name}');
      } else {
        SnackBarHelper.showError(
          context,
          'Failed to connect to ${device.name}',
        );
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      if (mounted) {
        AppLog.error('Connection error: $e');
        SnackBarHelper.showError(context, 'Connection error: $e');
      }
    }
  }

  Future<void> _disconnectPrinter() async {
    try {
      final success = await PrinterHelper.disconnect();
      if (success) {
        setState(() {
          _isConnected = false;
          PrinterHelper.connectedPrinterName = null;
        });
        if (!mounted) return;
        SnackBarHelper.showSuccess(context, 'Disconnected from printer');
      } else {
        if (!mounted) return;
        SnackBarHelper.showError(context, 'Failed to disconnect');
      }
    } catch (e) {
      if (!mounted) return;
      AppLog.error('Disconnect error: $e');
      SnackBarHelper.showError(context, 'Disconnect error: $e');
    }
  }

  Future<void> _setPaperSize(String macAddress, bool isMm80) async {
    await PrinterPreferences.setPaperMm80(macAddress, isMm80);
    setState(() => _paperMm80[macAddress] = isMm80);
  }

  Future<void> _printTest() async {
    if (!_isConnected) {
      SnackBarHelper.showWarning(context, 'Please connect to a printer first');
      return;
    }

    try {
      _showLoading('Printing test receipt...');

      final success = await PrinterHelper.printTestReceipt();

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (success) {
        SnackBarHelper.showSuccess(
          context,
          'Test receipt printed successfully',
        );
      } else {
        SnackBarHelper.showError(context, 'Failed to print test receipt');
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      if (mounted) {
        AppLog.error('Print error: $e');
        SnackBarHelper.showError(context, 'Print error: $e');
      }
    }
  }

  void _showLoading(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isFromTransaction,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Only show transaction-related dialogs if accessed from transaction
        if (!widget.isFromTransaction) {
          Navigator.pop(context);
          return;
        }

        // Check if printer is now connected
        final isNowConnected = await PrinterHelper.isConnected;

        if (isNowConnected) {
          if (!context.mounted) return;
          // Printer is connected, ask if user wants to retry printing
          final shouldRetry = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Printer Terhubung'),
              content: const Text(
                'Printer sekarang sudah terhubung. Apakah Anda ingin mencoba mencetak struk sekarang?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Tidak'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Ya, Print Struk'),
                ),
              ],
            ),
          );

          if (!context.mounted) return;
          Navigator.pop(context, shouldRetry);
        } else {
          if (!context.mounted) return;
          // Printer still not connected, ask if user wants to save without printing
          final shouldSave = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Printer Tidak Terhubung'),
              content: const Text(
                'Printer masih belum terhubung. Apakah Anda ingin menyimpan transaksi tanpa mencetak struk?',
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context, null), // Cancel transaction
                  child: const Text('Batal Transaksi'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Simpan Tanpa Print'),
                ),
              ],
            ),
          );

          if (!context.mounted) return;
          Navigator.pop(context, shouldSave);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Printer'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadPairedDevices,
            ),
          ],
        ),
        body: SafeArea(
          child: Builder(
            builder: (context) {
              final theme = Theme.of(context);
              final surfaces = context.surfaces;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Dimens.dp20,
                      Dimens.dp8,
                      Dimens.dp20,
                      Dimens.dp16,
                    ),
                    child: AppCard(
                      color: _isConnected ? surfaces.successTint : null,
                      borderColor: _isConnected ? Colors.transparent : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _isConnected
                                    ? Icons.bluetooth_connected_rounded
                                    : Icons.bluetooth_disabled_rounded,
                                size: 20,
                                color: _isConnected
                                    ? surfaces.onSuccessTint
                                    : surfaces.textMuted,
                              ),
                              const SizedBox(width: Dimens.dp12),
                              Expanded(
                                child: Text(
                                  _isConnected
                                      ? PrinterHelper.connectedPrinterName ??
                                            'Printer terhubung'
                                      : 'Belum ada printer terhubung',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: _isConnected
                                        ? surfaces.onSuccessTint
                                        : null,
                                  ),
                                ),
                              ),
                              if (_isConnected)
                                TextButton(
                                  onPressed: _disconnectPrinter,
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTokens.danger,
                                  ),
                                  child: const Text('Putuskan'),
                                ),
                            ],
                          ),
                          if (_isConnected) ...[
                            const SizedBox(height: Dimens.dp12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _printTest,
                                icon: const Icon(
                                  Icons.print_outlined,
                                  size: 20,
                                ),
                                label: const Text('Cetak Struk Uji'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  Expanded(
                    child: _isScanning
                        ? const Center(child: CircularProgressIndicator())
                        : _devices.isEmpty
                        ? EmptyState(
                            icon: Icons.bluetooth_searching_rounded,
                            title: 'Tidak ada printer',
                            message:
                                'Pasangkan printer lewat pengaturan Bluetooth '
                                'perangkat terlebih dahulu, lalu muat ulang.',
                            actionLabel: 'Muat Ulang',
                            onAction: _loadPairedDevices,
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              Dimens.dp20,
                              0,
                              Dimens.dp20,
                              Dimens.dp20,
                            ),
                            itemCount: _devices.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: Dimens.dp12),
                            itemBuilder: (context, index) {
                              final device = _devices[index];
                              final isCurrentDevice =
                                  PrinterHelper.connectedPrinterName ==
                                  device.name;

                              return AppCard(
                                onTap: isCurrentDevice
                                    ? null
                                    : () => _connectToPrinter(device),
                                borderColor: isCurrentDevice
                                    ? AppTokens.success
                                    : null,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.print_outlined,
                                          size: 20,
                                          color: isCurrentDevice
                                              ? AppTokens.success
                                              : surfaces.textSecondary,
                                        ),
                                        const SizedBox(width: Dimens.dp12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                device.name,
                                                style: theme
                                                    .textTheme
                                                    .titleMedium,
                                              ),
                                              Text(
                                                device.macAdress,
                                                style:
                                                    theme.textTheme.bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isCurrentDevice)
                                          const Icon(
                                            Icons.check_circle,
                                            size: 20,
                                            color: AppTokens.success,
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: Dimens.dp12),
                                    Row(
                                      children: [
                                        Text(
                                          'Ukuran kertas',
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                        const Spacer(),
                                        SegmentedButton<bool>(
                                          showSelectedIcon: false,
                                          style: const ButtonStyle(
                                            visualDensity:
                                                VisualDensity.compact,
                                            tapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                          ),
                                          segments: const [
                                            ButtonSegment(
                                              value: false,
                                              label: Text('58mm'),
                                            ),
                                            ButtonSegment(
                                              value: true,
                                              label: Text('80mm'),
                                            ),
                                          ],
                                          selected: {
                                            _paperMm80[device.macAdress] ??
                                                false,
                                          },
                                          onSelectionChanged: (selection) =>
                                              _setPaperSize(
                                                device.macAdress,
                                                selection.first,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
