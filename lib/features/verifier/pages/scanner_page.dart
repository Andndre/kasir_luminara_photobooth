import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kasir/features/verifier/blocs/verifier_bloc.dart';
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
      body: MobileScanner(
        onDetect: (capture) async {
          if (_isProcessing) return;
          
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null) {
              setState(() => _isProcessing = true);
              await _verifyTicket(barcode.rawValue!);
              setState(() => _isProcessing = false);
              break;
            }
          }
        },
      ),
    );
  }

  Future<void> _verifyTicket(String code) async {
    try {
      final result = await context.read<VerifierBloc>().service.verifyTicket(code);
      if (mounted) {
        _showResult(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showResult(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(result['valid'] ? 'Tiket VALID' : 'Tiket TIDAK VALID'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result['valid']) ...[
              const Icon(Icons.check_circle, color: Colors.green, size: 64),
              const SizedBox(height: 16),
              Text('Nama: ${result['data']['customer_name']}'),
              Text('Paket: ${result['data']['product_name']}'),
            ] else ...[
              const Icon(Icons.error, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(result['message'] ?? 'Tiket tidak ditemukan atau sudah dipakai.'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (result['valid']) {
                Navigator.pop(context); // Close scanner
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
