import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luminara_photobooth/features/verifier/blocs/verifier_bloc.dart';
import 'package:luminara_photobooth/model/log.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class TicketScannerPage extends StatefulWidget {
  const TicketScannerPage({super.key});

  @override
  State<TicketScannerPage> createState() => _TicketScannerPageState();
}

class _TicketScannerPageState extends State<TicketScannerPage> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Tiket')),
      body: SafeArea(
        child: MobileScanner(
          onDetect: (capture) async {
            if (_isProcessing) return;

            final List<Barcode> barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              if (barcode.rawValue != null) {
                setState(() => _isProcessing = true);
                await _verifyTicket(barcode.rawValue!);
                // _isProcessing reset is handled in _showResult or catch block
                break;
              }
            }
          },
        ),
      ),
    );
  }

  Future<void> _verifyTicket(String code) async {
    try {
      final result = await context.read<VerifierBloc>().service.verifyTicket(
        code,
      );
      if (mounted) {
        _showResult(result);
      } else {
        // If unmounted, reset processing state immediately
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      if (mounted) {
        Log.insertLog('Error verifying ticket: $e', isError: true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      // Reset state on error to allow retry
      setState(() => _isProcessing = false);
    }
  }

  void _showResult(Map<String, dynamic> result) {
    final data = result['data'] ?? {};
    final items = (data['items'] as List?) ?? [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          result['valid'] ? 'Tiket VALID' : 'Tiket TIDAK VALID',
          style: TextStyle(
            color: result['valid'] ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Icon(
                result['valid'] ? Icons.check_circle : Icons.error,
                color: result['valid'] ? Colors.green : Colors.red,
                size: 80,
              ),
            ),
            const SizedBox(height: 24),
            if (result['valid']) ...[
              const Text(
                'Data Pelanggan:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              Text(
                '${data['customer_name']}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Divider(height: 24),
              const Text(
                'Paket yang Dibeli:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 8),
              if (items.isEmpty)
                Text(data['product_name'] ?? '-')
              else
                ...items.map(
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.shopping_bag_outlined, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${i['product_name']} x${i['quantity']}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: const Text(
                  'Tiket berhasil diverifikasi dan ditandai sebagai COMPLETED.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.green, fontSize: 11),
                ),
              ),
            ] else ...[
              Center(
                child: Text(
                  result['message'] ??
                      'Tiket tidak ditemukan atau sudah dipakai.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _isProcessing = false); // Resume scanning

                if (result['valid']) {
                  Navigator.pop(context); // Close scanner on success
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: result['valid'] ? Colors.green : Colors.grey,
                foregroundColor: Colors.white,
              ),
              child: const Text('OK'),
            ),
          ),
        ],
      ),
    );
  }
}
