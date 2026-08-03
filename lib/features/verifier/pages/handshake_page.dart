import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luminara_photobooth/core/core.dart';
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

            final surfaces = context.surfaces;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(Dimens.dp24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    children: [
                      const SizedBox(height: Dimens.dp16),
                      Container(
                        width: 96,
                        height: 96,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isConnected
                              ? surfaces.successTint
                              : surfaces.surfaceAlt,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isConnected
                              ? Icons.cloud_done_rounded
                              : Icons.link_rounded,
                          size: 44,
                          color: isConnected
                              ? surfaces.onSuccessTint
                              : surfaces.textMuted,
                        ),
                      ),
                      const SizedBox(height: Dimens.dp24),
                      if (isConnected)
                        _buildConnectedInfo(context, state)
                      else
                        _buildConnectionForm(context, state),
                      if (state.errorMessage != null && !isConnected)
                        Padding(
                          padding: const EdgeInsets.only(top: Dimens.dp16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(Dimens.dp12),
                            decoration: BoxDecoration(
                              color: surfaces.dangerTint,
                              borderRadius: BorderRadius.circular(Dimens.rMd),
                            ),
                            child: Text(
                              state.errorMessage!,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: surfaces.onDangerTint),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildConnectedInfo(BuildContext context, VerifierState state) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text('Terhubung ke Server', style: theme.textTheme.titleLarge),
        const SizedBox(height: Dimens.dp4),
        Text(
          '${state.serverIp}',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: Dimens.dp32),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _confirmDisconnect(context),
            icon: const Icon(Icons.link_off_rounded, size: 20),
            label: const Text('Putuskan Koneksi'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTokens.danger,
              side: const BorderSide(color: AppTokens.danger),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionForm(BuildContext context, VerifierState state) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;
    final isConnecting = state.status == VerifierStatus.connecting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EyebrowText('Alamat Server'),
        const SizedBox(height: Dimens.dp8),
        TextField(
          controller: _ipController,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(hintText: '192.168.1.5'),
        ),
        const SizedBox(height: Dimens.dp16),
        ElevatedButton(
          onPressed: isConnecting
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
          child: Text(isConnecting ? 'Menghubungkan...' : 'Hubungkan'),
        ),
        const SizedBox(height: Dimens.dp24),
        Row(
          children: [
            Expanded(child: Divider(color: surfaces.border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimens.dp12),
              child: Text('ATAU', style: theme.textTheme.labelMedium),
            ),
            Expanded(child: Divider(color: surfaces.border)),
          ],
        ),
        const SizedBox(height: Dimens.dp24),
        OutlinedButton.icon(
          onPressed: _scanPairingQR,
          icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
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
            style: TextButton.styleFrom(foregroundColor: AppTokens.danger),
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
                    context.read<BottomNavBloc>().add(
                      TapBottomNavEvent(0),
                    ); // Go to Queue
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
