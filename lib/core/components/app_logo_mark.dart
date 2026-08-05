import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/preferences/assets.dart';

/// The app icon as a filled circle.
///
/// `app_icon.png` adalah persegi hitam pekat. Versi lama memberinya padding
/// 12% lalu menggambarnya di atas lingkaran hitam TANPA klip: sisi persegi
/// jadi 0,76 × diameter, sedangkan diagonalnya 1,08 × diameter — jadi keempat
/// sudutnya menyembul keluar lingkaran sebagai tonjolan kecil.
///
/// ClipOval-lah yang menentukan bentuknya sekarang. Padding tetap ada supaya
/// wordmark "Luminara Visual" tidak terpotong di tepi bawah; sudut persegi
/// yang tercukur hitam di atas hitam, jadi tak terlihat.
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        // Sewarna dengan latar asetnya sendiri, jadi tepi lingkarannya menyatu.
        color: const Color(0xFF000000),
        padding: EdgeInsets.all(size * 0.12),
        child: Image.asset(MainAssets.logo, fit: BoxFit.contain),
      ),
    );
  }
}
