import 'package:flutter/material.dart';

class Dimens {
  Dimens._();

  static width(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static height(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  // Responsive padding based on screen width
  static double responsivePadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 768) {
      return 64.0; // Tablet/Desktop
    } else if (screenWidth > 480) {
      return 32.0; // Large phone
    } else {
      return 16.0; // Phone
    }
  }

  // Alternative: Percentage-based padding
  static double percentagePadding(BuildContext context, double percentage) {
    return MediaQuery.of(context).size.width * percentage;
  }

  // Specific responsive padding for different components
  static double cardPadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth > 768 ? 64.0 : 16.0;
  }

  static double horizontalPadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1200) return 80.0; // Large desktop
    if (screenWidth > 768) return 64.0; // Tablet
    if (screenWidth > 480) return 24.0; // Large phone
    return 16.0; // Phone
  }

  static const defaultSize = 16.0;

  static const dp2 = 2.0;
  static const dp4 = 4.0;
  static const dp8 = 8.0;
  static const dp10 = 10.0;
  static const dp12 = 12.0;
  static const dp14 = 14.0;
  static const dp16 = 16.0;
  static const dp18 = 18.0;
  static const dp20 = 20.0;
  static const dp24 = 24.0;
  static const dp32 = 32.0;
  static const dp36 = 36.0;
  static const dp38 = 38.0;
  static const dp40 = 40.0;
  static const dp42 = 42.0;
  static const dp50 = 50.0;

  // Radius lama. Dipertahankan supaya layar yang belum dimigrasi tetap jalan;
  // layar baru pakai rSm..rFull di bawah. Lihat DESIGN.md §4.
  static const double radius = 4.0;
  static const double radiusMedium = 8.0;

  // --- Skala radius ---
  static const double rXs = 6.0; // badge status
  static const double rSm = 10.0; // elemen kecil di dalam kartu
  static const double rMd = 14.0; // input, kartu kecil berdiri sendiri
  static const double rLg = 18.0; // kartu, dialog
  static const double rXl = 24.0; // kartu hero
  static const double rFull = 999.0; // avatar, pil, FAB, SEMUA tombol

  /// Radius elemen dalam supaya sudutnya sejajar dengan sudut wadahnya:
  /// `luar = dalam + padding`.
  ///
  /// HANYA relevan untuk elemen yang benar-benar MENEMPEL di sudut wadah —
  /// gambar full-bleed, pil di dalam bar nav, sheet di dalam frame. Elemen
  /// yang mengambang di tengah (badge, avatar, tombol) tidak perlu ikut;
  /// memaksakannya justru bikin bentuk yang aneh.
  static double inner(double outer, double padding) {
    final r = outer - padding;
    return r < 4 ? 4 : r;
  }
}
