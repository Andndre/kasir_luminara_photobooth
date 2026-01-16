import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/features/home/blocs/blocs.dart';
import 'package:luminara_photobooth/features/verifier/blocs/verifier_bloc.dart';
import 'package:luminara_photobooth/features/verifier/blocs/verifier_state.dart';
import 'package:luminara_photobooth/features/verifier/pages/scanner_page.dart';
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
                          'icon': Icons.qr_code_scanner,
                          'color': Colors.blue,
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
                          'icon': Icons.list_alt,
                          'color': Colors.orange,
                          'onTap': () => context.read<BottomNavBloc>().add(
                            TapBottomNavEvent(1),
                          ),
                        },
                        {
                          'title': isConnected
                              ? 'Koneksi Aktif'
                              : 'Status Koneksi',
                          'icon': isConnected ? Icons.wifi : Icons.wifi_off,
                          'color': isConnected ? Colors.green : Colors.red,
                          'onTap': () => context.read<BottomNavBloc>().add(
                            TapBottomNavEvent(2),
                          ),
                        },
                        {
                          'title': 'Pengaturan',
                          'icon': Icons.settings,
                          'color': Colors.grey,
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
        color = Colors.green;
        label = 'Online';
        icon = Icons.check_circle;
        break;
      case VerifierStatus.connecting:
        color = Colors.orange;
        label = 'Connecting';
        icon = Icons.sync;
        break;
      case VerifierStatus.error:
        color = Colors.red;
        label = 'Error';
        icon = Icons.error;
        break;
      case VerifierStatus.disconnected:
        color = Colors.grey;
        label = 'Offline';
        icon = Icons.cloud_off;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context, VerifierState state) {
    final isConnected = state.status == VerifierStatus.connected;
    final primaryColor = isConnected ? Colors.purple : Colors.blueGrey;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor.shade600, primaryColor.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(Dimens.radius),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected ? 'Server Terhubung' : 'Server Terputus',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isConnected
                      ? 'Siap memverifikasi tiket di ${state.serverIp}'
                      : 'Silakan hubungkan ke server di menu Koneksi.',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Text(
                  DateFormat(
                    'EEEE, dd MMMM yyyy',
                    'id_ID',
                  ).format(DateTime.now()),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isConnected ? Icons.verified_user : Icons.gpp_maybe,
            color: Colors.white,
            size: 64,
          ),
        ],
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
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(Dimens.radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Dimens.radius),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleMedium?.color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
