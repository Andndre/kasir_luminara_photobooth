import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/preferences/assets.dart';

/// The app icon as a filled circle.
///
/// `app_icon.png` is a square with an opaque black background, so the circle is
/// painted in that same black and the logo sits inside with `contain` — cover
/// would crop the "Luminara Visual" wordmark at the bottom corners.
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        // Sewarna dengan latar asetnya sendiri, jadi tepi lingkarannya menyatu.
        color: Color(0xFF000000),
        shape: BoxShape.circle,
      ),
      padding: EdgeInsets.all(size * 0.12),
      child: Image.asset(MainAssets.logo, fit: BoxFit.contain),
    );
  }
}
