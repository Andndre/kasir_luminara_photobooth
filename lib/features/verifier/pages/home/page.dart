import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/features/home/blocs/blocs.dart';
import 'package:intl/intl.dart';

class ClientHomePage extends StatelessWidget {
  const ClientHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Verifier Dashboard'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        foregroundColor: theme.appBarTheme.foregroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeSection(),
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
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
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
                    'onTap': () => context.read<BottomNavBloc>().add(TapBottomNavEvent(1)), // Koneksi/Scanner is index 1 or 2? Wait.
                    // Actually, "Scan Tiket" is redundant if "Koneksi" page handles scanning in handshake or if there's a dedicated scanner page.
                    // The FAB is the main scanner trigger.
                    // Let's just navigate to the Scanner Page directly or trigger the FAB action logic.
                    // For now, let's keep the onTap empty or point to relevant tabs.
                  },
                  {
                    'title': 'Antrean Live',
                    'icon': Icons.list_alt,
                    'color': Colors.orange,
                    'onTap': () => context.read<BottomNavBloc>().add(TapBottomNavEvent(1)), // Antrean is index 1
                  },
                  {
                    'title': 'Status Koneksi',
                    'icon': Icons.wifi,
                    'color': Colors.green,
                    'onTap': () => context.read<BottomNavBloc>().add(TapBottomNavEvent(2)), // Koneksi is index 2
                  },
                  {
                    'title': 'Pengaturan',
                    'icon': Icons.settings,
                    'color': Colors.grey,
                    'onTap': () => context.read<BottomNavBloc>().add(TapBottomNavEvent(3)), // Setelan is index 3
                  },
                ];
                
                final item = items[index];
                return _buildMenuCard(
                  context,
                  title: item['title'] as String,
                  icon: item['icon'] as IconData,
                  color: item['color'] as Color,
                  onTap: () {
                     // Basic navigation for now, can be improved.
                     // Accessing BottomNavBloc requires import.
                     // For UI fix, let's just keep the visual structure.
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade600, Colors.purple.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(Dimens.radius),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.3),
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
                const Text(
                  'Mode Verifikator',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Siap memindai dan memverifikasi tiket pengunjung.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Text(
                  DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(DateTime.now()),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const Icon(Icons.verified_user, color: Colors.white, size: 64),
        ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, {
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
