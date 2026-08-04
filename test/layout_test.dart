import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luminara_photobooth/core/preferences/dimens.dart';
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
