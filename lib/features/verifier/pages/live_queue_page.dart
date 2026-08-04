import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/features/verifier/blocs/verifier_bloc.dart';
import 'package:luminara_photobooth/features/verifier/blocs/verifier_state.dart';
import 'package:intl/intl.dart';

/// Kartu antrean. Nomor antrean dibuat besar karena itu yang dicocokkan
/// petugas dengan tiket di tangan pelanggan, dari jarak berdiri.
class _QueueCard extends StatelessWidget {
  const _QueueCard({
    required this.ticket,
    required this.fallbackNumber,
    required this.onTap,
  });

  final QueueTicket ticket;
  final int fallbackNumber;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;
    final items = ticket.items;
    final createdAt = ticket.createdAt;
    final timeStr = createdAt == null
        ? '-'
        : DateFormat('HH:mm').format(createdAt);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Dimens.dp12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: surfaces.brandTint,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${ticket.queueNumber ?? fallbackNumber}',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: Dimens.dp12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ticket.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Text(timeStr, style: theme.textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: Dimens.dp8),
                if (items.isEmpty)
                  Text(ticket.summary, style: theme.textTheme.bodyMedium)
                else
                  ...items.map(
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: Dimens.dp4),
                      child: Row(
                        children: [
                          PackageMonogram(i.productName, size: 24),
                          const SizedBox(width: Dimens.dp8),
                          Expanded(
                            child: Text(
                              '${i.productName} ×${i.quantity}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: Dimens.dp4),
                Row(
                  children: [
                    const StatusBadge(TransactionStatus.paid),
                    const SizedBox(width: Dimens.dp8),
                    Expanded(
                      child: Text(
                        ticket.uuid,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LiveQueuePage extends StatelessWidget {
  const LiveQueuePage({super.key});

  void _showVerifyDialog(BuildContext context, QueueTicket ticket) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true, // bentuk & radius diambil dari bottomSheetTheme
      builder: (ctx) => _VerifyBottomSheet(
        ticket: ticket,
        onVerify: () {
          context.read<VerifierBloc>().add(VerifyTransaction(ticket.uuid));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Antrean Real-time')),
      body: SafeArea(
        child: BlocListener<VerifierBloc, VerifierState>(
          listenWhen: (previous, current) =>
              previous.verifySuccess != current.verifySuccess ||
              (previous.errorMessage != current.errorMessage &&
                  current.errorMessage != null),
          listener: (context, state) {
            if (state.verifySuccess) {
              SnackBarHelper.showSuccess(
                context,
                'Tiket berhasil diverifikasi',
              );
            } else if (state.errorMessage != null &&
                state.verifyingUuid == null &&
                state.status == VerifierStatus.connected) {
              SnackBarHelper.showError(context, state.errorMessage!);
            }
          },
          child: BlocBuilder<VerifierBloc, VerifierState>(
            builder: (context, state) {
              if (state.status == VerifierStatus.disconnected) {
                return const EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Belum terhubung',
                  message:
                      'Hubungkan ke server lewat menu Koneksi untuk '
                      'melihat antrean.',
                );
              }

              if (state.status == VerifierStatus.error && state.queue.isEmpty) {
                return EmptyState(
                  isError: true,
                  icon: Icons.cloud_off_rounded,
                  title: 'Gagal mengambil antrean',
                  message: state.errorMessage,
                  actionLabel: 'Coba Lagi',
                  onAction: () =>
                      context.read<VerifierBloc>().add(RefreshQueue()),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  context.read<VerifierBloc>().add(RefreshQueue());
                },
                child: state.queue.isEmpty
                    ? const EmptyState(
                        icon: Icons.done_all_rounded,
                        title: 'Antrean kosong',
                        message: 'Semua tiket sudah dilayani.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(Dimens.dp16),
                        itemCount: state.queue.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: Dimens.dp12),
                        itemBuilder: (context, index) {
                          final ticket = state.queue[index];
                          return _QueueCard(
                            ticket: ticket,
                            fallbackNumber: index + 1,
                            onTap: () => _showVerifyDialog(context, ticket),
                          );
                        },
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _VerifyBottomSheet extends StatelessWidget {
  final QueueTicket ticket;
  final VoidCallback onVerify;

  const _VerifyBottomSheet({required this.ticket, required this.onVerify});

  @override
  Widget build(BuildContext context) {
    final items = ticket.items;

    return BlocListener<VerifierBloc, VerifierState>(
      listenWhen: (previous, current) =>
          previous.verifySuccess != current.verifySuccess &&
          current.verifySuccess,
      listener: (context, state) {
        if (state.verifySuccess) {
          Navigator.pop(context);
        }
      },
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final surfaces = context.surfaces;

          return Padding(
            padding: const EdgeInsets.fromLTRB(
              Dimens.dp24,
              0,
              Dimens.dp24,
              Dimens.dp24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: surfaces.brandTint,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${ticket.queueNumber ?? '-'}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(width: Dimens.dp16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const EyebrowText('Konfirmasi Verifikasi'),
                          const SizedBox(height: Dimens.dp4),
                          Text(
                            ticket.customerName,
                            style: theme.textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Dimens.dp24),
                const EyebrowText('Layanan'),
                const SizedBox(height: Dimens.dp12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        if (items.isEmpty)
                          Text(ticket.summary, style: theme.textTheme.bodyLarge)
                        else
                          ...items.map(
                            (i) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: Dimens.dp8,
                              ),
                              child: Row(
                                children: [
                                  PackageMonogram(i.productName, size: 32),
                                  const SizedBox(width: Dimens.dp12),
                                  Expanded(
                                    child: Text(
                                      '${i.productName} ×${i.quantity}',
                                      style: theme.textTheme.bodyLarge,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Dimens.dp24),
                BlocBuilder<VerifierBloc, VerifierState>(
                  builder: (context, state) {
                    final isVerifying = state.verifyingUuid == ticket.uuid;

                    return Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: isVerifying ? null : onVerify,
                            child: isVerifying
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('VERIFIKASI SEKARANG'),
                          ),
                        ),
                        const SizedBox(height: Dimens.dp8),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: isVerifying
                                ? null
                                : () => Navigator.pop(context),
                            child: const Text('Batal'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
