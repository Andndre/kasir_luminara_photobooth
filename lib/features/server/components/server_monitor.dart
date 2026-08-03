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
        final statusColor = isOnline ? AppTokens.success : AppTokens.danger;

        final surfaces = context.surfaces;

        // Online: satu baris ringkas. Offline: melebar + tombol nyalakan.
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: Dimens.dp8),
                  Expanded(
                    child: Text(
                      isOnline ? 'Aktif' : 'Tidak aktif',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (isOnline)
                    TextButton.icon(
                      onPressed: () => _showPairingQR(context, state),
                      icon: const Icon(Icons.qr_code_rounded, size: 18),
                      label: const Text('Pairing QR'),
                    ),
                ],
              ),
              if (isOnline) ...[
                const SizedBox(height: Dimens.dp4),
                Text(
                  '${state.ipAddress ?? '-'} : ${state.port}  ·  '
                  '${state.connectedClients} perangkat terhubung',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: surfaces.textMuted,
                  ),
                ),
              ] else ...[
                const SizedBox(height: Dimens.dp12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        context.read<ServerBloc>().add(StartServer()),
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text('Nyalakan Server'),
                  ),
                ),
              ],
              if (state.errorMessage != null) ...[
                const SizedBox(height: Dimens.dp8),
                Text(
                  state.errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
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
