import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/features/home/home.dart';
import 'package:luminara_photobooth/features/kasir/pages/kasir.dart';
import 'package:luminara_photobooth/features/product/product.dart';
import 'package:luminara_photobooth/features/settings/pages/pages.dart';
import 'package:luminara_photobooth/features/transaction/pages/index/page.dart';

import 'package:luminara_photobooth/core/constants/app_mode.dart';
import 'package:luminara_photobooth/features/verifier/pages/live_queue_page.dart';
import 'package:luminara_photobooth/features/verifier/pages/handshake_page.dart';
import 'package:luminara_photobooth/features/verifier/pages/scanner_page.dart';

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  static const String routeName = '/main';

  @override
  Widget build(BuildContext context) {
    final mode = context.read<AppMode>();

    final serverPages = <Widget>[
      const HomePage(),
      const TransactionPage(),
      const ProductPage(),
      const SettingPage(),
    ];

    final clientPages = <Widget>[
      const LiveQueuePage(),
      const HandshakePage(),
      const SettingPage(),
    ];

    final pages = mode == AppMode.server ? serverPages : clientPages;

    return BlocBuilder<BottomNavBloc, int>(
      builder: (context, index) {
        // Ensure index is within range for clientPages if mode changed
        final safeIndex = index >= pages.length ? 0 : index;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: pages[safeIndex],
          bottomNavigationBar: BottomAppBar(
            shape: null,
            clipBehavior: Clip.none,
            elevation: 2.0,
            height: 70,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: mode == AppMode.server ? [
                  Flexible(
                    child: _NavItem(
                      icon: AppIcons.storefront,
                      label: 'Beranda',
                      isActive: safeIndex == 0,
                      onTap: () {
                        context.read<BottomNavBloc>().add(TapBottomNavEvent(0));
                      },
                    ),
                  ),
                  Flexible(
                    child: _NavItem(
                      icon: AppIcons.receipt,
                      label: 'Transaksi',
                      isActive: safeIndex == 1,
                      onTap: () {
                        context.read<BottomNavBloc>().add(TapBottomNavEvent(1));
                      },
                    ),
                  ),
                  const SizedBox(width: 84),
                  Flexible(
                    child: _NavItem(
                      icon: AppIcons.product,
                      label: 'Produk',
                      isActive: safeIndex == 2,
                      onTap: () {
                        context.read<BottomNavBloc>().add(TapBottomNavEvent(2));
                      },
                    ),
                  ),
                  Flexible(
                    child: _NavItem(
                      icon: AppIcons.settings,
                      label: 'Pengaturan',
                      isActive: safeIndex == 3,
                      onTap: () {
                        context.read<BottomNavBloc>().add(TapBottomNavEvent(3));
                      },
                    ),
                  ),
                ] : [
                  Flexible(
                    child: _NavItem(
                      icon: Icons.list_alt,
                      label: 'Antrean',
                      isActive: safeIndex == 0,
                      onTap: () {
                        context.read<BottomNavBloc>().add(TapBottomNavEvent(0));
                      },
                    ),
                  ),
                  const SizedBox(width: 84),
                  Flexible(
                    child: _NavItem(
                      icon: Icons.link,
                      label: 'Koneksi',
                      isActive: safeIndex == 1,
                      onTap: () {
                        context.read<BottomNavBloc>().add(TapBottomNavEvent(1));
                      },
                    ),
                  ),
                  Flexible(
                    child: _NavItem(
                      icon: Icons.settings,
                      label: 'Setelan',
                      isActive: safeIndex == 2,
                      onTap: () {
                        context.read<BottomNavBloc>().add(TapBottomNavEvent(2));
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              if (mode == AppMode.server) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const Kasir()),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TicketScannerPage()),
                );
              }
            },
            tooltip: mode == AppMode.server ? 'Tambah Transaksi' : 'Scan Tiket',
            elevation: 2.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(mode == AppMode.server ? Icons.point_of_sale : Icons.qr_code_scanner, size: 32),
          ),
        );
      },
    );
  }
}

// Custom Navigation Item Component with Advanced Animations
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minWidth: 48),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.0, end: isActive ? 1.1 : 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.elasticOut,
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Icon(
                    icon,
                    color: isActive ? AppColors.primary : AppColors.textDisabled,
                    size: isActive ? 24 : 22,
                  ),
                );
              },
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              crossFadeState: isActive
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
          ],
        ),
      ),
    );
  }
}
