import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/features/home/home.dart';
import 'package:luminara_photobooth/features/cashier/cashier.dart';
import 'package:luminara_photobooth/features/product/product.dart';
import 'package:luminara_photobooth/features/settings/pages/pages.dart';
import 'package:luminara_photobooth/features/transaction/transaction.dart';

import 'package:luminara_photobooth/core/constants/app_mode.dart';
import 'package:luminara_photobooth/features/verifier/pages/live_queue_page.dart';
import 'package:luminara_photobooth/features/verifier/pages/ticket_scanner_page.dart';

import 'package:luminara_photobooth/features/verifier/pages/client_home_page.dart';
import 'package:luminara_photobooth/core/services/update_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Satu entri navigasi. Dipakai bersama oleh NavigationRail (desktop) dan
/// NavigationBar mengambang (mobile) supaya labelnya tidak pernah beda.
typedef NavEntry = ({IconData icon, String label});

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  static const String routeName = '/main';

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {

  static const _serverNav = <NavEntry>[
    (icon: AppIcons.storefront, label: 'Beranda'),
    (icon: AppIcons.receipt, label: 'Transaksi'),
    (icon: AppIcons.product, label: 'Produk'),
    (icon: AppIcons.settings, label: 'Setelan'),
  ];

  // Tidak ada tab "Koneksi": akun yang menjadi pasangannya, dan itu sudah
  // didapat saat login. Halaman lamanya cuma membalik sebuah boolean lokal.
  static const _clientNav = <NavEntry>[
    (icon: AppIcons.storefront, label: 'Beranda'),
    (icon: Icons.list_alt_rounded, label: 'Antrean'),
    (icon: Icons.settings_rounded, label: 'Setelan'),
  ];

  @override
  void initState() {
    super.initState();
    _checkUpdate();
  }

  /// Sekali per nyala aplikasi, dan tidak menghalangi apa pun.
  ///
  /// Diletakkan di sini, bukan di Setelan: yang memegang perangkat sepanjang
  /// hari adalah petugas yang tidak pernah membuka Setelan. Berbentuk SnackBar,
  /// bukan dialog, karena aplikasi ini bisa saja sedang di tengah transaksi
  /// saat jawabannya datang.
  Future<void> _checkUpdate() async {
    final update = await UpdateService.check();
    if (!mounted || update == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Versi ${update.version} sudah tersedia'),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: 'Unduh',
          onPressed: () => launchUrl(
            update.url,
            mode: LaunchMode.externalApplication,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mode = context.read<AppMode>();
    final isDesktop = MediaQuery.of(context).size.width > 700;
    final isServer = mode == AppMode.server;

    final pages = isServer
        ? const <Widget>[
            HomePage(),
            TransactionPage(),
            ProductPage(),
            SettingsPage(),
          ]
        : const <Widget>[
            ClientHomePage(),
            LiveQueuePage(),
            SettingsPage(),
          ];

    final nav = isServer ? _serverNav : _clientNav;

    return BlocBuilder<BottomNavBloc, int>(
      builder: (context, index) {
        final safeIndex = index >= pages.length ? 0 : index;
        void select(int i) =>
            context.read<BottomNavBloc>().add(TapBottomNavEvent(i));

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDesktop)
                  NavigationRail(
                    selectedIndex: safeIndex,
                    onDestinationSelected: select,
                    labelType: NavigationRailLabelType.all,
                    minWidth: 88,
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: Dimens.dp24,
                      ),
                      child: Image.asset(MainAssets.logo, width: 36),
                    ),
                    // Tanpa Expanded: rail dipasang dengan
                    // CrossAxisAlignment.start (aturan stabilitas #7) sehingga
                    // tingginya tidak terikat — Expanded di sini akan throw.
                    trailing: Padding(
                      padding: const EdgeInsets.only(top: Dimens.dp32),
                      child: _ActionButton(mode: mode),
                    ),
                    destinations: [
                      for (final e in nav)
                        NavigationRailDestination(
                          icon: Icon(e.icon),
                          label: Text(e.label),
                        ),
                    ],
                  ),
                Expanded(
                  child: Column(
                    children: [
                      // Hanya mode kasir: verifier tidak memegang sewa apa pun.
                      if (isServer) const CashierLeaseBanner(),
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
              ],
            ),
          ),
          floatingActionButton: isDesktop ? null : _ActionButton(mode: mode),
          bottomNavigationBar: isDesktop
              ? null
              : FloatingNavBar(
                  entries: nav,
                  selectedIndex: safeIndex,
                  onSelect: select,
                ),
        );
      },
    );
  }
}

/// Bar mengambang: margin dari tepi, sudut besar, item aktif jadi pill.
/// Menggantikan BottomAppBar bertakik + label 8px yang lama.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.entries,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<NavEntry> entries;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  /// Jarak bar mengambang ke tepi bawah layar.
  ///
  /// SafeArea polos memberi inset penuh — di HP gesture hasilnya menggantung
  /// terlalu tinggi. Aturannya:
  ///   0      : tanpa system nav (desktop/tablet)      → 12
  ///   ≤ 34   : gesture pill (Android 24, iPhone 34)   → 45%-nya, minimum 10
  ///   > 34   : tombol navigasi 3-tombol (± 48)        → penuh + 4, jangan tertimpa
  @visibleForTesting
  static double bottomGapFor(double inset) {
    if (inset <= 0) return Dimens.dp12;
    if (inset <= 34) {
      final half = inset * 0.45;
      return half < 10 ? 10 : half;
    }
    return inset + Dimens.dp4;
  }

  /// Tinggi pil item. Radius bar = padding + setengah tinggi pil, jadi sudut
  /// pil dan sudut bar benar-benar sejajar (§4 DESIGN.md).
  static const double _pillHeight = 44;
  static const double _barPadding = 6;
  static const double _pillGap = 4;
  static double get _barRadius => _barPadding + _pillHeight / 2; // 28

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final bottomGap = bottomGapFor(MediaQuery.viewPaddingOf(context).bottom);

    return Padding(
      padding: EdgeInsets.fromLTRB(Dimens.dp16, 0, Dimens.dp16, bottomGap),
      child: Container(
        padding: const EdgeInsets.all(_barPadding),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(_barRadius),
          border: Border.all(color: surfaces.border),
          boxShadow: surfaces.cardShadow,
        ),
        // Lebar pil diambil dari lebar bar, bukan dari isinya. Dengan
        // spaceEvenly sisa ruang menganggur di kiri-kanan dan barnya terlihat
        // setengah kosong; sekarang isinya selalu memenuhi wadahnya.
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Sela antar-pil disisihkan dulu, baru sisanya dibagi: pil aktif
            // dapat dua bagian, sisanya satu bagian masing-masing.
            final gaps = _pillGap * (entries.length - 1);
            final unit = (constraints.maxWidth - gaps) / (entries.length + 1);

            return Row(
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  if (i > 0) const SizedBox(width: _pillGap),
                  _NavPill(
                    entry: entries[i],
                    selected: i == selectedIndex,
                    width: i == selectedIndex ? unit * 2 : unit,
                    height: _pillHeight,
                    onTap: () => onSelect(i),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Item nav. Semua item punya latar pil supaya hitbox-nya kelihatan;
/// yang aktif memakai tint brand + label di samping ikon, yang tidak aktif
/// memakai tint netral dan hanya ikon.
class _NavPill extends StatelessWidget {
  const _NavPill({
    required this.entry,
    required this.selected,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final NavEntry entry;
  final bool selected;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;

    return Semantics(
      selected: selected,
      button: true,
      label: entry.label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // Dua warna opaque, bukan fade ke transparan — lerp ke
            // Colors.transparent (hitam alpha 0) berkedip gelap di tengah.
            color: selected ? surfaces.brandTint : surfaces.surfaceAlt,
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                entry.icon,
                size: 22,
                color: selected
                    ? theme.colorScheme.primary
                    : surfaces.textMuted,
              ),
              // Label menyusut jadi 0 saat tidak aktif, jadi ia tersingkap
              // seiring pil melebar, bukan muncul begitu saja di tengahnya.
              // Flexible + ellipsis: di layar sempit "Transaksi" lebih lebar
              // dari jatah pilnya.
              Flexible(
                child: ClipRect(
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.centerLeft,
                    widthFactor: selected ? 1 : 0,
                    child: Padding(
                      padding: const EdgeInsets.only(left: Dimens.dp8),
                      child: Text(
                        entry.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aksi utama per mode: buka Kasir (server) atau Scan Tiket (verifier).
class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.mode});

  final AppMode mode;

  @override
  Widget build(BuildContext context) {
    final isServer = mode == AppMode.server;

    return Tooltip(
      message: isServer ? 'Transaksi Baru' : 'Scan Tiket',
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: AppTokens.heroGradient(Theme.of(context).brightness),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTokens.brand600.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    isServer ? const CashierPage() : const TicketScannerPage(),
              ),
            ),
            child: Icon(
              isServer
                  ? Icons.point_of_sale_rounded
                  : Icons.qr_code_scanner_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
