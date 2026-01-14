import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luminara_photobooth/features/home/blocs/blocs.dart';
import 'package:luminara_photobooth/features/verifier/blocs/verifier_bloc.dart';
import 'package:luminara_photobooth/features/verifier/blocs/verifier_state.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class HandshakePage extends StatefulWidget {
  const HandshakePage({super.key});

  @override
  State<HandshakePage> createState() => _HandshakePageState();
}

class _HandshakePageState extends State<HandshakePage> {
  final _ipController = TextEditingController();
  bool _isProcessing = false; // Guard flag

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Koneksi ke Server')),
      body: BlocBuilder<VerifierBloc, VerifierState>(
        builder: (context, state) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Icon(Icons.link, size: 80, color: Colors.blue),
                const SizedBox(height: 24),
                TextField(
                  controller: _ipController,
                  decoration: const InputDecoration(
                    labelText: 'Server IP (e.g. 192.168.1.5)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: state.status == VerifierStatus.connecting
                        ? null
                        : () {
                            final parts = _ipController.text.split(':');
                            if (parts.isNotEmpty) {
                              final ip = parts[0];
                              final port = parts.length > 1 ? int.parse(parts[1]) : 3000;
                              context.read<VerifierBloc>().add(ConnectToServer(ip, port));
                              // Navigate to Live Queue (Index 0)
                              context.read<BottomNavBloc>().add(TapBottomNavEvent(0));
                            }
                          },
                    child: Text(state.status == VerifierStatus.connecting
                        ? 'Menghubungkan...'
                        : 'Hubungkan'),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('ATAU'),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => _scanPairingQR(),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan Pairing QR'),
                ),
                const SizedBox(height: 48),
                if (state.status == VerifierStatus.connected)
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Terhubung ke Server', style: TextStyle(color: Colors.green)),
                    ],
                  ),
                if (state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Text(
                      'Error: ${state.errorMessage}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _scanPairingQR() {
    setState(() => _isProcessing = false); // Reset before scan
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Scan Pairing QR')),
          body: MobileScanner(
            onDetect: (capture) {
              if (_isProcessing) return; // Ignore multiple calls

              final barcode = capture.barcodes.first;
              if (barcode.rawValue != null) {
                final data = barcode.rawValue!;
                final parts = data.split(':');
                if (parts.isNotEmpty) {
                  setState(() => _isProcessing = true);
                  
                  final ip = parts[0];
                  final port = parts.length > 1 ? int.parse(parts[1]) : 3000;
                  context.read<VerifierBloc>().add(ConnectToServer(ip, port));
                  
                  if (context.mounted) {
                    Navigator.pop(context); // Close scanner safely
                    context.read<BottomNavBloc>().add(TapBottomNavEvent(0)); // Go to Queue
                  }
                }
              }
            },
          ),
        ),
      ),
    );
  }
}