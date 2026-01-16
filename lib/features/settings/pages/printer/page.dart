import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/helpers/printer.dart';
import 'package:luminara_photobooth/core/helpers/snackbar_helper.dart';
import 'package:luminara_photobooth/model/log.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

class PrinterPage extends StatefulWidget {
  final bool isFromTransaction;

  const PrinterPage({super.key, this.isFromTransaction = false});

  @override
  State<PrinterPage> createState() => _PrinterPageState();
}

class _PrinterPageState extends State<PrinterPage> {
  List<BluetoothInfo> _devices = [];
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
      setState(() => _devices = devices);
    } catch (e) {
      if (mounted) {
        Log.insertLog('Error loading paired devices: $e', isError: true);
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
        Log.insertLog('Connection error: $e', isError: true);
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
      Log.insertLog('Disconnect error: $e', isError: true);
      SnackBarHelper.showError(context, 'Disconnect error: $e');
    }
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
        Log.insertLog('Print error: $e', isError: true);
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
          child: Column(
            children: [
              // Connection Status
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: _isConnected ? Colors.green[100] : Colors.red[100],
                child: Row(
                  children: [
                    Icon(
                      _isConnected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_disabled,
                      color: _isConnected ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isConnected
                            ? 'Connected to: ${PrinterHelper.connectedPrinterName ?? "Unknown"}'
                            : 'Not connected to any printer',
                        style: TextStyle(
                          color: _isConnected
                              ? Colors.green[800]
                              : Colors.red[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (_isConnected)
                      TextButton(
                        onPressed: _disconnectPrinter,
                        child: const Text('Disconnect'),
                      ),
                  ],
                ),
              ),

              // Test Print Button
              if (_isConnected)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _printTest,
                          icon: const Icon(Icons.print),
                          label: const Text('Print Test Receipt'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Device List
              Expanded(
                child: _isScanning
                    ? const Center(child: CircularProgressIndicator())
                    : _devices.isEmpty
                    ? const Center(
                        child: Text(
                          'No paired bluetooth devices found.\nPlease pair your printer first.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        itemCount: _devices.length,
                        itemBuilder: (context, index) {
                          final device = _devices[index];
                          final isCurrentDevice =
                              PrinterHelper.connectedPrinterName == device.name;

                          return ListTile(
                            leading: Icon(
                              Icons.print,
                              color: isCurrentDevice ? Colors.green : null,
                            ),
                            title: Text(
                              device.name,
                              style: TextStyle(
                                fontWeight: isCurrentDevice
                                    ? FontWeight.bold
                                    : null,
                                color: isCurrentDevice ? Colors.green : null,
                              ),
                            ),
                            subtitle: Text(
                              device.macAdress,
                              style: TextStyle(
                                color: isCurrentDevice
                                    ? Colors.green[600]
                                    : null,
                              ),
                            ),
                            trailing: isCurrentDevice
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  )
                                : null,
                            onTap: isCurrentDevice
                                ? null
                                : () => _connectToPrinter(device),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
