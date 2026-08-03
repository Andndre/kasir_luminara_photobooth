import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/constants/app_mode.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/core/preferences/app_state.dart';
import 'package:provider/provider.dart';

class ModeSelectionPage extends StatelessWidget {
  const ModeSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const EyebrowText('Luminara Photobooth'),
                const SizedBox(height: Dimens.dp8),
                Text(
                  'Pilih Mode Perangkat',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: Dimens.dp8),
                Text(
                  'Bisa diganti kapan saja lewat menu Setelan.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: Dimens.dp32),
                _ModeCard(
                  title: 'Kasir',
                  icon: Icons.point_of_sale_rounded,
                  description:
                      'Menjual paket, mencetak tiket, dan menjalankan '
                      'server di jaringan lokal.',
                  onTap: () {
                    context.read<AppState>().setMode(AppMode.server);
                  },
                ),
                const SizedBox(height: Dimens.dp16),
                _ModeCard(
                  title: 'Verifier',
                  icon: Icons.qr_code_scanner_rounded,
                  description:
                      'Memindai tiket pelanggan di booth dan melihat '
                      'antrean secara langsung.',
                  onTap: () {
                    context.read<AppState>().setMode(AppMode.client);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.icon,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;

    return SizedBox(
      width: 400,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(Dimens.dp20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: surfaces.brandTint,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 26, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: Dimens.dp16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: Dimens.dp4),
                  Text(description, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: surfaces.textMuted,
              size: Dimens.dp20,
            ),
          ],
        ),
      ),
    );
  }
}
