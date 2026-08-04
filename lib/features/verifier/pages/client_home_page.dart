import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/features/home/blocs/blocs.dart';
import 'package:luminara_photobooth/features/verifier/blocs/verifier_bloc.dart';
import 'package:luminara_photobooth/features/verifier/blocs/verifier_state.dart';
import 'package:luminara_photobooth/features/verifier/pages/ticket_scanner_page.dart';
import 'package:intl/intl.dart';

class ClientHomePage extends StatelessWidget {
  const ClientHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<VerifierBloc, VerifierState>(
      builder: (context, state) {
        final isConnected = state.status == VerifierStatus.connected;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text('Verifier Dashboard'),
            backgroundColor: theme.appBarTheme.backgroundColor,
            elevation: 0,
            foregroundColor: theme.appBarTheme.foregroundColor,
            actions: [_buildConnectionChip(state), const SizedBox(width: 16)],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeSection(context, state),
                  const SizedBox(height: 32),
                  Text(
                    'Menu Cepat',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.titleLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 200,
                          mainAxisExtent: 160,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    itemCount: 4,
                    itemBuilder: (context, index) {
                      final items = [
                        {
                          'title': 'Scan Tiket',
                          'icon': Icons.qr_code_scanner_rounded,
                          'color': theme.colorScheme.primary,
                          'onTap': () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const TicketScannerPage(),
                              ),
                            );
                          },
                        },
                        {
                          'title': 'Antrean Live',
                          'icon': Icons.list_alt_rounded,
                          'color': AppTokens.accent600,
                          'onTap': () => context.read<BottomNavBloc>().add(
                            TapBottomNavEvent(1),
                          ),
                        },
                        {
                          'title': isConnected
                              ? 'Koneksi Aktif'
                              : 'Status Koneksi',
                          'icon': isConnected
                              ? Icons.wifi_rounded
                              : Icons.wifi_off_rounded,
                          'color': isConnected
                              ? AppTokens.success
                              : AppTokens.danger,
                          'onTap': () => context.read<BottomNavBloc>().add(
                            TapBottomNavEvent(2),
                          ),
                        },
                        {
                          'title': 'Pengaturan',
                          'icon': Icons.settings_rounded,
                          'color': context.surfaces.textSecondary,
                          'onTap': () => context.read<BottomNavBloc>().add(
                            TapBottomNavEvent(3),
                          ),
                        },
                      ];

                      final item = items[index];
                      return _buildMenuCard(
                        context,
                        title: item['title'] as String,
                        icon: item['icon'] as IconData,
                        color: item['color'] as Color,
                        onTap: item['onTap'] as VoidCallback,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConnectionChip(VerifierState state) {
    Color color;
    String label;
    IconData icon;

    switch (state.status) {
      case VerifierStatus.connected:
        color = AppTokens.success;
        label = 'Online';
        icon = Icons.check_circle;
        break;
      case VerifierStatus.connecting:
        color = AppTokens.warning;
        label = 'Menghubungkan';
        icon = Icons.sync;
        break;
      case VerifierStatus.error:
        color = AppTokens.danger;
        label = 'Error';
        icon = Icons.error;
        break;
      case VerifierStatus.disconnected:
        color = AppTokens.wine800;
        label = 'Offline';
        icon = Icons.cloud_off;
        break;
    }

    return Builder(
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Dimens.dp12,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Dimens.rFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context, VerifierState state) {
    final isConnected = state.status == VerifierStatus.connected;

    return HeroPanel(
      label: isConnected ? 'Server Terhubung' : 'Server Terputus',
      value: isConnected ? (state.serverIp ?? '-') : 'Belum terhubung',
      meta: isConnected
          ? 'Siap memverifikasi tiket · ${DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(DateTime.now())}'
          : 'Hubungkan lewat menu Koneksi.',
      icon: isConnected ? Icons.verified_user_rounded : Icons.gpp_maybe_rounded,
      // Terputus bukan kondisi brand — pakai tinta netral, bukan wine.
      gradient: isConnected
          ? null
          : const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3D332F), Color(0xFF1A1412)],
            ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return AppCard(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: Dimens.dp12),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
