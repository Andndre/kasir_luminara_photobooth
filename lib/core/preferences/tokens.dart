import 'package:flutter/material.dart';

/// Token desain Luminara Photobooth. Lihat DESIGN.md di root repo.
///
/// Warna yang SAMA di kedua tema tinggal di sini. Warna yang BERBEDA per tema
/// ada di [AppSurfaces] supaya ikut berganti otomatis saat tema diganti.
class AppTokens {
  AppTokens._();

  // --- Brand: Editorial Wine & Gold ---
  // Nilai diambil langsung dari sumber web luminarabali.com
  // (resources/css/app.css `.catalog` + resources/views/booking.blade.php),
  // bukan dari tabel divisi di DESIGN.md web yang sudah tertinggal.
  static const wine800 = Color(0xFF3A0F1C);
  static const wine700 = Color(0xFF461320); // pressed / hover
  static const brand600 = Color(0xFF5B1A2B); // --cat-wine  PRIMARY
  static const brand500 = Color(0xFF7A2438);
  static const brand400 = Color(0xFFA63B52); // primary di dark mode
  static const brand300 = Color(0xFFC2566E); // teks/ikon aksen di dark mode

  static const gold700 = Color(0xFF8A6D2C);
  static const accent600 = Color(0xFFB08D3C); // --cat-gold  GOLD
  static const accent500 = Color(0xFFC9A227);
  static const accent400 = Color(0xFFE7C97A); // gold di atas wine/dark

  /// Garis rambut emas — pemisah utama di web (`--cat-hair`).
  /// Di aplikasi ini dipakai sebagai border kartu di light mode.
  static const hairline = Color(0x59B08D3C); // rgba(176,141,60,.35)

  // --- Semantik (solid) ---
  static const success = Color(0xFF166534);
  static const warning = Color(0xFF92400E);
  static const danger = Color(0xFFDC2626);
  static const info = Color(0xFF2F5D62);

  /// Aksen paket, dipilih deterministik lewat [packageAccent].
  /// Palet hangat/editorial supaya menyatu dengan Wine & Gold.
  static const packageAccents = <Color>[
    Color(0xFF5B1A2B), // wine
    Color(0xFFB08D3C), // gold
    Color(0xFFA14A2A), // terracotta
    Color(0xFF5F6B3A), // olive
    Color(0xFF2F5D62), // deep teal
    Color(0xFF6E3B5C), // plum
  ];

  /// Warna tetap untuk satu nama paket, supaya identitasnya konsisten di
  /// semua layar tanpa perlu menyimpan apa pun di database.
  static Color packageAccent(String name) =>
      packageAccents[name.hashCode.abs() % packageAccents.length];

  /// Gradien hero: wine dalam, gelap ke kanan-bawah. Aksen gold dipakai untuk
  /// teks label kecil di atasnya, bukan sebagai ujung gradien (jadi lumpur).
  /// Maksimal satu elemen per layar.
  static LinearGradient heroGradient(Brightness brightness) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: brightness == Brightness.dark
        ? const [brand600, Color(0xFF2A0B14)]
        : const [Color(0xFF6B1E33), wine700],
  );
}

/// Warna permukaan & teks yang berbeda antara light dan dark.
///
/// PENTING: setiap field WAJIB ikut di [copyWith] dan [lerp]. Field yang
/// terlewat menyebabkan warna melompat (atau crash) saat animasi ganti tema.
@immutable
class AppSurfaces extends ThemeExtension<AppSurfaces> {
  const AppSurfaces({
    required this.surfaceAlt,
    required this.border,
    required this.borderStrong,
    required this.textSecondary,
    required this.textMuted,
    required this.brandTint,
    required this.successTint,
    required this.warningTint,
    required this.dangerTint,
    required this.infoTint,
    required this.onSuccessTint,
    required this.onWarningTint,
    required this.onDangerTint,
    required this.onInfoTint,
    required this.shadowColor,
  });

  final Color surfaceAlt;
  final Color border;
  final Color borderStrong;
  final Color textSecondary;
  final Color textMuted;
  final Color brandTint;
  final Color successTint;
  final Color warningTint;
  final Color dangerTint;
  final Color infoTint;
  final Color onSuccessTint;
  final Color onWarningTint;
  final Color onDangerTint;
  final Color onInfoTint;

  /// Transparan di dark mode — kedalaman dibuat lewat border, bukan bayangan.
  final Color shadowColor;

  /// Krem + ivory + garis rambut emas, persis identitas web.
  static const light = AppSurfaces(
    surfaceAlt: Color(0xFFF1EADF), // input, kartu bertingkat
    border: AppTokens.hairline,
    borderStrong: Color(0x8CB08D3C),
    textSecondary: Color(0xFF6B625C),
    textMuted: Color(0xFF9A8F86),
    brandTint: Color(0xFFF4E8EA),
    successTint: Color(0xFFDCFCE7),
    warningTint: Color(0xFFFEF3C7),
    dangerTint: Color(0xFFFEE2E2),
    infoTint: Color(0xFFE3EDEE),
    onSuccessTint: Color(0xFF166534),
    onWarningTint: Color(0xFF92400E),
    onDangerTint: Color(0xFF991B1B),
    onInfoTint: Color(0xFF2F5D62),
    shadowColor: Color(0x1F1A1412), // rgba(26,20,18,.12)
  );

  /// Web-nya light-only, jadi dark mode diturunkan: dasar cokelat-tinta
  /// (bukan abu netral) supaya tetap terasa hangat & satu keluarga.
  static const dark = AppSurfaces(
    surfaceAlt: Color(0xFF2A2320),
    border: Color(0xFF332B27),
    borderStrong: Color(0x40B08D3C),
    textSecondary: Color(0xFFB5A99E),
    textMuted: Color(0xFF857A70),
    brandTint: Color(0xFF2E1219),
    successTint: Color(0xFF10321E),
    warningTint: Color(0xFF3A2A0B),
    dangerTint: Color(0xFF3D1414),
    infoTint: Color(0xFF12292B),
    onSuccessTint: Color(0xFF86D8A5),
    onWarningTint: Color(0xFFE7C97A),
    onDangerTint: Color(0xFFF0A3A3),
    onInfoTint: Color(0xFF8FBFC4),
    shadowColor: Color(0x00000000),
  );

  /// Bayangan ambient untuk kartu. Kosong di dark mode.
  List<BoxShadow> get cardShadow => shadowColor.a == 0
      ? const []
      : [
          BoxShadow(
            color: shadowColor,
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ];

  @override
  AppSurfaces copyWith({
    Color? surfaceAlt,
    Color? border,
    Color? borderStrong,
    Color? textSecondary,
    Color? textMuted,
    Color? brandTint,
    Color? successTint,
    Color? warningTint,
    Color? dangerTint,
    Color? infoTint,
    Color? onSuccessTint,
    Color? onWarningTint,
    Color? onDangerTint,
    Color? onInfoTint,
    Color? shadowColor,
  }) {
    return AppSurfaces(
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      brandTint: brandTint ?? this.brandTint,
      successTint: successTint ?? this.successTint,
      warningTint: warningTint ?? this.warningTint,
      dangerTint: dangerTint ?? this.dangerTint,
      infoTint: infoTint ?? this.infoTint,
      onSuccessTint: onSuccessTint ?? this.onSuccessTint,
      onWarningTint: onWarningTint ?? this.onWarningTint,
      onDangerTint: onDangerTint ?? this.onDangerTint,
      onInfoTint: onInfoTint ?? this.onInfoTint,
      shadowColor: shadowColor ?? this.shadowColor,
    );
  }

  @override
  AppSurfaces lerp(covariant AppSurfaces? other, double t) {
    if (other == null) return this;
    return AppSurfaces(
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      brandTint: Color.lerp(brandTint, other.brandTint, t)!,
      successTint: Color.lerp(successTint, other.successTint, t)!,
      warningTint: Color.lerp(warningTint, other.warningTint, t)!,
      dangerTint: Color.lerp(dangerTint, other.dangerTint, t)!,
      infoTint: Color.lerp(infoTint, other.infoTint, t)!,
      onSuccessTint: Color.lerp(onSuccessTint, other.onSuccessTint, t)!,
      onWarningTint: Color.lerp(onWarningTint, other.onWarningTint, t)!,
      onDangerTint: Color.lerp(onDangerTint, other.onDangerTint, t)!,
      onInfoTint: Color.lerp(onInfoTint, other.onInfoTint, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
    );
  }
}

extension AppSurfacesX on BuildContext {
  /// `context.surfaces.warningTint`
  AppSurfaces get surfaces => Theme.of(this).extension<AppSurfaces>()!;
}
