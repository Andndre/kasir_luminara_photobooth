import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luminara_photobooth/features/verifier/blocs/verifier_bloc.dart';
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
      final result = await context.read<VerifierBloc>().service.verifyTicket(code);
      if (mounted) {
        _showResult(result);
      } else {
        // If unmounted, reset processing state immediately
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
      // Reset state on error to allow retry
      setState(() => _isProcessing = false);
    }
  }

  void _showResult(Map<String, dynamic> result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(result['valid'] ? 'Tiket VALID' : 'Tiket TIDAK VALID'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Icon(
                result['valid'] ? Icons.check_circle : Icons.error,
                color: result['valid'] ? Colors.green : Colors.red,
                size: 64,
              ),
            ),
            const SizedBox(height: 16),
            if (result['valid']) ...[
              Text('Nama: ${result['data']['customer_name']}'),
              Text('Paket: ${result['data']['product_name']}'),
            ] else ...[
              Text(result['message'] ?? 'Tiket tidak ditemukan atau sudah dipakai.'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isProcessing = false); // Resume scanning
              
              if (result['valid']) {
                Navigator.pop(context); // Close scanner on success
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
