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
    final theme = Theme.of(context);
    
    return BlocBuilder<ServerBloc, ServerState>(
      builder: (context, state) {
        final isOnline = state.status == ServerStatus.online;
        final statusColor = isOnline ? Colors.green : Colors.red;
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(Dimens.radius),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.3),
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
              LayoutBuilder(
                builder: (context, constraints) {
                  // Switch to column layout on narrow screens (< 450px)
                  final isNarrow = constraints.maxWidth < 450;
                  
                  Widget statusWidget = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOnline ? Icons.dns : Icons.dns_outlined,
                        color: statusColor,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Server Status: ${state.status.name.toUpperCase()}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  );

                  Widget actionButton = isOnline
                      ? ElevatedButton.icon(
                          onPressed: () => _showPairingQR(context, state),
                          icon: const Icon(Icons.qr_code, size: 18),
                          label: const Text('Pairing QR'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: () {
                            context.read<ServerBloc>().add(StartServer());
                          },
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: const Text('Start Server'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        statusWidget,
                        const SizedBox(height: 12),
                        actionButton,
                      ],
                    );
                  } else {
                    return Row(
                      children: [
                        Expanded(child: statusWidget),
                        const SizedBox(width: 8),
                        actionButton,
                      ],
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              if (isOnline) ...[
                _buildInfoRow('IP Address', state.ipAddress ?? '-', theme),
                _buildInfoRow('Port', '${state.port}', theme),
                _buildInfoRow('Connected Clients', '${state.connectedClients}', theme),
              ],
              if (state.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Error: ${state.errorMessage}',
                    style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
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
                backgroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
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