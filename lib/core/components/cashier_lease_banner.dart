import 'package:flutter/material.dart';

import '../preferences/dimens.dart';
import '../helpers/snackbar_helper.dart';
import '../preferences/tokens.dart';
import '../services/cashier_lease_service.dart';

/// Menawarkan pengambilalihan peran kasir, dan melakukannya kalau disetujui.
///
/// Konfirmasinya tegas dengan sengaja: dua perangkat yang sama-sama merasa
/// berhak jadi kasir adalah persis keadaan yang mau dicegah seluruh rancangan
/// ini, jadi merebutnya harus jadi tindakan sadar, bukan ketukan tak sengaja.
///
/// Returns true kalau perangkat ini akhirnya boleh menjual.
Future<bool> confirmCashierTakeover(BuildContext context) async {
  final lease = CashierLeaseService();
  if (lease.state.canSell) return true;

  final holder = lease.holder;
  final takeOver = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Ambil alih peran kasir?'),
      content: Text(
        holder == null
            ? 'Perangkat lain sedang jadi kasir. Setelah diambil alih, '
                  'perangkat itu berhenti bisa menjual.'
            : 'Peran kasir sedang dipegang ${holder.deviceName}. Setelah '
                  'diambil alih, perangkat itu berhenti bisa menjual.\n\n'
                  'Pastikan tidak ada yang sedang melayani pelanggan di sana.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: AppTokens.danger),
          child: const Text('Ambil Alih'),
        ),
      ],
    ),
  );

  if (takeOver != true || !context.mounted) return false;

  await lease.claim(force: true);
  if (!context.mounted) return false;

  if (!lease.state.canSell) {
    SnackBarHelper.showError(context, 'Gagal mengambil alih peran kasir');
    return false;
  }
  return true;
}

/// Bilah tipis yang menyatakan keadaan peran kasir perangkat ini.
///
/// Ada karena AKTIF OFFLINE tidak boleh terlihat sama dengan AKTIF. Perangkat
/// yang kehilangan internet tetap menjual, tapi sewanya tidak bisa dipastikan
/// lagi dan perangkat lain boleh mengambil alih setelah 90 detik — kalau itu
/// terjadi tanpa ada yang terlihat berubah di layar, dua orang akan menjual
/// dengan nomor antrian yang sama tanpa satu pun menyadarinya.
class CashierLeaseBanner extends StatelessWidget {
  const CashierLeaseBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CashierLeaseService(),
      builder: (context, _) {
        final lease = CashierLeaseService();
        final notice = _noticeFor(lease.state, lease.holder);
        if (notice == null) return const SizedBox.shrink();

        final theme = Theme.of(context);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: Dimens.dp16,
            vertical: Dimens.dp10,
          ),
          color: notice.color.withValues(alpha: 0.12),
          child: Row(
            children: [
              Icon(notice.icon, size: 18, color: notice.color),
              const SizedBox(width: Dimens.dp8),
              Expanded(
                child: Text(
                  notice.message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.surfaces.textSecondary,
                  ),
                ),
              ),
              // Jalan keluarnya ada di tempat masalahnya diberitahukan. Tanpa
              // ini satu-satunya cara mengambil alih adalah pura-pura menjual
              // sampai layar bayar, yang tidak akan ditemukan siapa pun.
              if (!lease.state.canSell) ...[
                const SizedBox(width: Dimens.dp8),
                TextButton(
                  onPressed: () => confirmCashierTakeover(context),
                  style: TextButton.styleFrom(
                    foregroundColor: notice.color,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimens.dp12,
                    ),
                  ),
                  child: const Text('Ambil Alih'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  static ({String message, Color color, IconData icon})? _noticeFor(
    CashierLeaseState state,
    LeaseHolder? holder,
  ) => switch (state) {
    // Keadaan normal tidak perlu bilah: kasir yang berfungsi bukan kabar.
    CashierLeaseState.active => null,
    CashierLeaseState.checking => null,

    CashierLeaseState.activeOffline => (
      message:
          'Tidak terhubung ke server. Penjualan tetap tercatat dan akan '
          'terkirim nanti.',
      color: AppTokens.warning,
      icon: Icons.cloud_off_rounded,
    ),

    CashierLeaseState.locked => (
      message:
          'Perangkat ini bukan kasir — peran itu dipegang '
          '${holder?.deviceName ?? 'perangkat lain'}.',
      color: AppTokens.danger,
      icon: Icons.lock_outline_rounded,
    ),

    CashierLeaseState.released => (
      message: 'Peran kasir sudah diambil alih perangkat lain.',
      color: AppTokens.danger,
      icon: Icons.lock_outline_rounded,
    ),
  };
}
