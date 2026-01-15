import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luminara_photobooth/features/home/blocs/blocs.dart';
import 'package:luminara_photobooth/features/verifier/blocs/verifier_bloc.dart';
import 'package:luminara_photobooth/features/verifier/blocs/verifier_state.dart';
import 'package:luminara_photobooth/core/preferences/verifier_preferences.dart';
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
  void initState() {
    super.initState();
    _loadSavedIp();
  }

  Future<void> _loadSavedIp() async {
    final saved = await VerifierPreferences.getServerAddress();
    if (saved != null && mounted) {
      _ipController.text = saved['ip'];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Koneksi ke Server')),
      body: SafeArea(
        child: BlocBuilder<VerifierBloc, VerifierState>(
          builder: (context, state) {
            final isConnected = state.status == VerifierStatus.connected;

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Icon(
                      isConnected ? Icons.cloud_done : Icons.link,
                      size: 80,
                      color: isConnected ? Colors.green : Colors.blue,
                    ),
                    const SizedBox(height: 24),
                    if (isConnected) ...[
                      _buildConnectedInfo(context, state),
                    ] else ...[
                      _buildConnectionForm(context, state),
                    ],
                    if (state.errorMessage != null && !isConnected)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Text(
                          'Error: ${state.errorMessage}',
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildConnectedInfo(BuildContext context, VerifierState state) {
    return Column(
      children: [
        const Text(
          'Terhubung ke Server',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'IP Address: ${state.serverIp}',
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 48),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _confirmDisconnect(context),
            icon: const Icon(Icons.link_off, color: Colors.red),
            label: const Text(
              'Putuskan Koneksi',
              style: TextStyle(color: Colors.red),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionForm(BuildContext context, VerifierState state) {
    return Column(
      children: [
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
                      final port =
                          parts.length > 1 ? int.parse(parts[1]) : 3000;
                      context
                          .read<VerifierBloc>()
                          .add(ConnectToServer(ip, port));
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
      ],
    );
  }

  void _confirmDisconnect(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Putuskan Koneksi?'),
        content: const Text(
          'Anda akan terputus dari server. Verifikasi tiket tidak dapat dilakukan sampai terhubung kembali.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              context.read<VerifierBloc>().add(DisconnectFromServer());
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Putuskan'),
          ),
        ],
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