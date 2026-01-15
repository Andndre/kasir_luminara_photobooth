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

import 'package:luminara_photobooth/features/verifier/pages/home/page.dart';

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  static const String routeName = '/main';

  @override
  Widget build(BuildContext context) {
    final mode = context.read<AppMode>();
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 700;

    final serverPages = <Widget>[
      const HomePage(),
      const TransactionPage(),
      const ProductPage(),
      const SettingPage(),
    ];

    final clientPages = <Widget>[
      const ClientHomePage(),
      const LiveQueuePage(),
      const HandshakePage(),
      const SettingPage(),
    ];

    final pages = mode == AppMode.server ? serverPages : clientPages;

    return BlocBuilder<BottomNavBloc, int>(
      builder: (context, index) {
        final safeIndex = index >= pages.length ? 0 : index;

                return Scaffold(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  body: SafeArea(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isDesktop)
                          NavigationRail(
                            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                            selectedIndex: safeIndex,
                            onDestinationSelected: (i) =>
                                context.read<BottomNavBloc>().add(TapBottomNavEvent(i)),
                            labelType: NavigationRailLabelType.all,
                            indicatorColor: AppColors.primary,
                            selectedIconTheme: const IconThemeData(color: Colors.white),
                            unselectedIconTheme:
                                const IconThemeData(color: AppColors.textDisabled),
                            leading: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Image.asset(MainAssets.logo, width: 40),
                            ),
                            trailing: Padding(
                              padding: const EdgeInsets.only(top: 24, bottom: 24),
                              child: FloatingActionButton(
                                onPressed: () => _handleFabAction(context, mode),
                                foregroundColor: Colors.white,
                                child: Icon(mode == AppMode.server
                                    ? Icons.point_of_sale
                                    : Icons.qr_code_scanner),
                              ),
                            ),
                            destinations: mode == AppMode.server
                                ? [
                                    const NavigationRailDestination(
                                      icon: Icon(AppIcons.storefront),
                                      label: Text('Beranda'),
                                    ),
                                    const NavigationRailDestination(
                                      icon: Icon(AppIcons.receipt),
                                      label: Text('Transaksi'),
                                    ),
                                    const NavigationRailDestination(
                                      icon: Icon(AppIcons.product),
                                      label: Text('Produk'),
                                    ),
                                    const NavigationRailDestination(
                                      icon: Icon(AppIcons.settings),
                                      label: Text('Setelan'),
                                    ),
                                  ]
                                : [
                                    const NavigationRailDestination(
                                      icon: Icon(AppIcons.storefront),
                                      label: Text('Beranda'),
                                    ),
                                    const NavigationRailDestination(
                                      icon: Icon(Icons.list_alt),
                                      label: Text('Antrean'),
                                    ),
                                    const NavigationRailDestination(
                                      icon: Icon(Icons.link),
                                      label: Text('Koneksi'),
                                    ),
                                    const NavigationRailDestination(
                                      icon: Icon(Icons.settings),
                                      label: Text('Setelan'),
                                    ),
                                  ],
                          ),
                        Expanded(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1200),
                              child: pages[safeIndex],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  bottomNavigationBar: isDesktop              ? null
              : BottomAppBar(
                  shape: const CircularNotchedRectangle(),
                  clipBehavior: Clip.antiAlias,
                  elevation: 2.0,
                  height: 70,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: mode == AppMode.server
                          ? [
                              Flexible(
                                child: _NavItem(
                                  icon: AppIcons.storefront,
                                  label: 'Beranda',
                                  isActive: safeIndex == 0,
                                  onTap: () {
                                    context
                                        .read<BottomNavBloc>()
                                        .add(TapBottomNavEvent(0));
                                  },
                                ),
                              ),
                              Flexible(
                                child: _NavItem(
                                  icon: AppIcons.receipt,
                                  label: 'Transaksi',
                                  isActive: safeIndex == 1,
                                  onTap: () {
                                    context
                                        .read<BottomNavBloc>()
                                        .add(TapBottomNavEvent(1));
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
                                    context
                                        .read<BottomNavBloc>()
                                        .add(TapBottomNavEvent(2));
                                  },
                                ),
                              ),
                              Flexible(
                                child: _NavItem(
                                  icon: AppIcons.settings,
                                  label: 'Pengaturan',
                                  isActive: safeIndex == 3,
                                  onTap: () {
                                    context
                                        .read<BottomNavBloc>()
                                        .add(TapBottomNavEvent(3));
                                  },
                                ),
                              ),
                            ]
                          : [
                              Flexible(
                                child: _NavItem(
                                  icon: AppIcons.storefront,
                                  label: 'Beranda',
                                  isActive: safeIndex == 0,
                                  onTap: () {
                                    context
                                        .read<BottomNavBloc>()
                                        .add(TapBottomNavEvent(0));
                                  },
                                ),
                              ),
                              Flexible(
                                child: _NavItem(
                                  icon: Icons.list_alt,
                                  label: 'Antrean',
                                  isActive: safeIndex == 1,
                                  onTap: () {
                                    context
                                        .read<BottomNavBloc>()
                                        .add(TapBottomNavEvent(1));
                                  },
                                ),
                              ),
                              const SizedBox(width: 84),
                              Flexible(
                                child: _NavItem(
                                  icon: Icons.link,
                                  label: 'Koneksi',
                                  isActive: safeIndex == 2,
                                  onTap: () {
                                    context
                                        .read<BottomNavBloc>()
                                        .add(TapBottomNavEvent(2));
                                  },
                                ),
                              ),
                              Flexible(
                                child: _NavItem(
                                  icon: Icons.settings,
                                  label: 'Setelan',
                                  isActive: safeIndex == 3,
                                  onTap: () {
                                    context
                                        .read<BottomNavBloc>()
                                        .add(TapBottomNavEvent(3));
                                  },
                                ),
                              ),
                            ],
                    ),
                  ),
                ),
          floatingActionButtonLocation: isDesktop
              ? null
              : FloatingActionButtonLocation.centerDocked,
          floatingActionButton: isDesktop
              ? null
              : FloatingActionButton(
                  onPressed: () => _handleFabAction(context, mode),
                  foregroundColor: Colors.white,
                  tooltip:
                      mode == AppMode.server ? 'Tambah Transaksi' : 'Scan Tiket',
                  elevation: 2.0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(mode == AppMode.server
                      ? Icons.point_of_sale
                      : Icons.qr_code_scanner, size: 32),
                ),
        );
      },
    );
  }

  void _handleFabAction(BuildContext context, AppMode mode) {
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
      borderRadius: BorderRadius.circular(Dimens.radius),
      child: Container(
        constraints: const BoxConstraints(minWidth: 48),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.0, end: isActive ? 1.1 : 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.elasticOut,
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.primary : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: isActive ? Colors.white : AppColors.textDisabled,
                      size: isActive ? 18 : 22,
                    ),
                  ),
                );
              },
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Text(
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
