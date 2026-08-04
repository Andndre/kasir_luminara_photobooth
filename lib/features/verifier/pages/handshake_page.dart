import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/core/services/auth_service.dart';
import 'package:luminara_photobooth/features/home/blocs/blocs.dart';
import 'package:luminara_photobooth/features/verifier/blocs/verifier_bloc.dart';
import 'package:luminara_photobooth/features/verifier/blocs/verifier_state.dart';

/// Status sambungan ke antrian.
///
/// Dulu halaman ini meminta alamat IP kasir, lengkap dengan pemindai QR
/// pairing. Sekarang akun yang jadi pasangannya, jadi tidak ada yang perlu
/// diketik — yang tersisa hanya menyambung dan memutus.
class HandshakePage extends StatelessWidget {
  const HandshakePage({super.key});

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
                              : Icons.cloud_off_rounded,
                          size: 44,
                          color: isConnected
                              ? surfaces.onSuccessTint
                              : surfaces.textMuted,
                        ),
                      ),
                      const SizedBox(height: Dimens.dp24),
                      if (isConnected)
                        _ConnectedInfo(state: state)
                      else
                        const _ConnectForm(),
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
}

class _ConnectedInfo extends StatelessWidget {
  const _ConnectedInfo({required this.state});

  final VerifierState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text('Terhubung', style: theme.textTheme.titleLarge),
        const SizedBox(height: Dimens.dp4),
        Text(
          AuthService().email ?? 'luminarabali.com',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
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

  void _confirmDisconnect(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Putuskan Koneksi?'),
        content: const Text(
          'Antrian berhenti diperbarui dan tiket tidak dapat diverifikasi '
          'sampai Anda menyambung kembali.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              context.read<VerifierBloc>().add(DisconnectFromServer());
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: AppTokens.danger),
            child: const Text('Putuskan'),
          ),
        ],
      ),
    );
  }
}

class _ConnectForm extends StatelessWidget {
  const _ConnectForm();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;
    final isConnecting =
        context.watch<VerifierBloc>().state.status == VerifierStatus.connecting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Antrian diambil dari akun yang sedang masuk, jadi perangkat ini '
          'tidak perlu satu Wi-Fi dengan kasir — tapi keduanya butuh internet.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: surfaces.textMuted,
          ),
        ),
        const SizedBox(height: Dimens.dp24),
        ElevatedButton.icon(
          onPressed: isConnecting
              ? null
              : () {
                  context.read<VerifierBloc>().add(ConnectToServer());
                  context.read<BottomNavBloc>().add(TapBottomNavEvent(0));
                },
          icon: const Icon(Icons.cloud_sync_outlined, size: 20),
          label: Text(isConnecting ? 'Menghubungkan...' : 'Hubungkan'),
        ),
      ],
    );
  }
}
