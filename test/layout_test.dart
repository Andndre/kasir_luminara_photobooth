import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luminara_photobooth/core/preferences/dimens.dart';
import 'package:luminara_photobooth/core/preferences/theme/app_theme.dart';
import 'package:luminara_photobooth/core/components/app_logo_mark.dart';
import 'package:luminara_photobooth/core/components/surface/status_badge.dart';
import 'package:luminara_photobooth/features/home/pages/main_page.dart';

void main() {
  group('Jarak bawah bottom nav', () {
    test('tanpa system nav → 12', () {
      expect(FloatingNavBar.bottomGapFor(0), Dimens.dp12);
    });

    test('gesture pill rapat, tidak menggantung', () {
      // Android gesture (24) & iPhone (34) harus jauh lebih kecil dari inset.
      expect(FloatingNavBar.bottomGapFor(24), lessThan(24));
      expect(FloatingNavBar.bottomGapFor(34), lessThan(34));
      // ...tapi tidak menempel ke tepi.
      expect(FloatingNavBar.bottomGapFor(24), greaterThanOrEqualTo(10));
    });

    test('tombol navigasi 3-tombol → bar tetap di ATAS tombol', () {
      // Kalau <= inset, bar tertimpa tombol sistem.
      expect(FloatingNavBar.bottomGapFor(48), greaterThan(48));
    });
  });

  group('Bottom nav memenuhi wadahnya', () {
    const nav = <NavEntry>[
      (icon: Icons.home, label: 'Beranda'),
      (icon: Icons.receipt, label: 'Transaksi'),
      (icon: Icons.inventory, label: 'Produk'),
      (icon: Icons.settings, label: 'Setelan'),
    ];

    Future<void> pumpAt(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          // Tema aplikasi, bukan default: FloatingNavBar membaca AppSurfaces.
          theme: buildAppTheme(Brightness.light),
          home: Scaffold(
            bottomNavigationBar: FloatingNavBar(
              entries: nav,
              selectedIndex: 1, // "Transaksi" — label terpanjang
              onSelect: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('pil terpanjang tidak meluber di layar sempit', (tester) async {
      // 320dp adalah HP terkecil yang masih dipakai; kalau jatah pilnya kurang
      // labelnya harus di-ellipsis, bukan bikin garis kuning overflow.
      await pumpAt(tester, 320);
      expect(tester.takeException(), isNull);
    });

    testWidgets('lebar semua pil menghabiskan lebar bar', (tester) async {
      await pumpAt(tester, 400);

      final pills = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .toList();
      expect(pills, hasLength(nav.length));

      final total = pills
          .map((p) => tester.getSize(find.byWidget(p)).width)
          .reduce((a, b) => a + b);
      // Lebar dalam bar = 400 - margin 16*2 - padding 6*2 - border 1*2,
      // dikurangi tiga sela 4px antar-pil.
      expect(total, closeTo(400 - 32 - 12 - 2 - 12, 0.5));
    });
  });

  group('Radius', () {
    test('bar nav konsentris dengan pil di dalamnya', () {
      // Pil setinggi 44 (radius 22) + padding bar 6 → radius bar 28.
      // Ini SATU-SATUNYA tempat rumus konsentris berlaku: pil benar-benar
      // menempel di sudut dalam bar.
      const pillRadius = 44 / 2;
      const barPadding = 6.0;
      // Radius bar dihitung dari pil, bukan diambil dari skala rSm..rXl.
      expect(Dimens.inner(pillRadius + barPadding, barPadding), pillRadius);
    });

    test('skala menaik dan tidak ada yang tajam', () {
      expect(Dimens.rXs, lessThan(Dimens.rSm));
      expect(Dimens.rSm, lessThan(Dimens.rMd));
      expect(Dimens.rMd, lessThan(Dimens.rLg));
      expect(Dimens.rLg, lessThan(Dimens.rXl));
      // Kartu tidak boleh setajam radius lama (4) atau segembung 24.
      expect(Dimens.rLg, inInclusiveRange(16, 20));
    });

    test('tidak pernah negatif', () {
      expect(Dimens.inner(8, 40), greaterThanOrEqualTo(4));
    });
  });

  group('Logo tetap bulat', () {
    // Induk dengan batasan lebar yang ketat pernah membuatnya jadi elips
    // selebar layar: `width`/`height` pada Container cuma usulan.
    testWidgets('tidak melar di Column stretch', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: const Scaffold(
            body: SizedBox(
              width: 400,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [AppLogoMark(size: 72)],
              ),
            ),
          ),
        ),
      );

      final oval = tester.getSize(find.byType(ClipOval));
      expect(oval.width, 72);
      expect(oval.height, 72);
    });
  });

  group('Fade tanpa kedip gelap', () {
    // Colors.transparent = HITAM dengan alpha 0. Melerp warna terang ke sana
    // melewati hitam semi-transparan → kilatan gelap di tengah animasi.
    const tint = Color(0xFFF4E8EA);

    test('Colors.transparent memang menggelap di tengah (penyebabnya)', () {
      final mid = Color.lerp(tint, Colors.transparent, 0.5)!;
      expect(mid.r, lessThan(tint.r));
      expect(mid.g, lessThan(tint.g));
      expect(mid.b, lessThan(tint.b));
    });

    test('fade lewat alpha warna sendiri menjaga RGB tetap', () {
      final mid = Color.lerp(tint, tint.withValues(alpha: 0), 0.5)!;
      expect(mid.r, closeTo(tint.r, 0.001));
      expect(mid.g, closeTo(tint.g, 0.001));
      expect(mid.b, closeTo(tint.b, 0.001));
      expect(mid.a, closeTo(0.5, 0.001));
    });
  });

  group('Monogram paket', () {
    test('dua kata → dua inisial', () {
      expect(PackageMonogram.initials('Self Photo 15 Menit'), 'SP');
      expect(PackageMonogram.initials('Wide Angle'), 'WA');
    });

    test('satu kata → dua huruf pertama', () {
      expect(PackageMonogram.initials('Photobooth'), 'PH');
    });

    test('input aneh tidak bikin crash', () {
      expect(PackageMonogram.initials(''), '?');
      expect(PackageMonogram.initials('   '), '?');
      expect(PackageMonogram.initials('A'), 'A');
    });
  });
}
