import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/features/server/blocs/server_bloc.dart';
import 'package:luminara_photobooth/features/server/blocs/server_state.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ServerMonitor extends StatelessWidget {
  const ServerMonitor({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ServerBloc, ServerState>(
      builder: (context, state) {
        final isOnline = state.status == ServerStatus.online;
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(Dimens.radius),
            border: Border.all(
              color: isOnline ? Colors.green.shade200 : Colors.red.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
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
                  Icon(
                    isOnline ? Icons.dns : Icons.dns_outlined,
                    color: isOnline ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Server Status: ${state.status.name.toUpperCase()}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isOnline ? Colors.green : Colors.red,
                    ),
                  ),
                  const Spacer(),
                  if (state.status == ServerStatus.online)
                    ElevatedButton.icon(
                      onPressed: () => _showPairingQR(context, state),
                      icon: const Icon(Icons.qr_code, size: 18),
                      label: const Text('Pairing QR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () {
                        context.read<ServerBloc>().add(StartServer());
                      },
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('Start Server'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (isOnline) ...[
                Text('IP Address: ${state.ipAddress}'),
                Text('Port: ${state.port}'),
                Text('Connected Clients: ${state.connectedClients}'),
              ],
              if (state.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Error: ${state.errorMessage}',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showPairingQR(BuildContext context, ServerState state) {
    final pairingData = '${state.ipAddress}:${state.port}';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pairing QR'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Scan this from the Verifier app to connect.'),
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              height: 200,
              child: QrImageView(
                data: pairingData,
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              pairingData,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}