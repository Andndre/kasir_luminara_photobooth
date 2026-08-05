import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/preferences/assets.dart';

/// The app icon cropped to a circle.
///
/// `app_icon.png` is a square with an opaque black background, so clipping it
/// to a circle only trims black corners — the "Luminara Visual" wordmark sits
/// well inside the inscribed circle. Sebelumnya ada padding 12% yang membuat
/// logonya mengambang kecil di tengah, tidak sama dengan yang di Setelan.
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(
        MainAssets.logo,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}
