import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luminara_photobooth/core/preferences/tokens.dart';
import 'package:luminara_photobooth/core/preferences/theme/app_theme.dart';

/// Menjaga aturan stabilitas: light dan dark harus punya properti identik.
/// Kalau timpang, aplikasi crash "Failed to interpolate TextStyles" saat
/// tema diganti — dan itu baru ketahuan di tangan kasir.
void main() {
  final light = buildAppTheme(Brightness.light);
  final dark = buildAppTheme(Brightness.dark);

  test('AppSurfaces terpasang di kedua tema', () {
    expect(light.extension<AppSurfaces>(), isNotNull);
    expect(dark.extension<AppSurfaces>(), isNotNull);
  });

  test('TextTheme punya himpunan style yang sama', () {
    TextStyle? pick(TextTheme t, int i) => [
      t.displaySmall,
      t.headlineLarge,
      t.headlineMedium,
      t.headlineSmall,
      t.titleLarge,
      t.titleMedium,
      t.bodyLarge,
      t.bodyMedium,
      t.bodySmall,
      t.labelLarge,
      t.labelMedium,
      t.labelSmall,
    ][i];

    for (var i = 0; i < 12; i++) {
      final l = pick(light.textTheme, i);
      final d = pick(dark.textTheme, i);
      expect(l, isNotNull, reason: 'style #$i kosong di light');
      expect(d, isNotNull, reason: 'style #$i kosong di dark');
      // fontFamily & fontSize wajib sama; hanya warna yang boleh beda.
      expect(l!.fontFamily, d!.fontFamily, reason: 'fontFamily beda di #$i');
      expect(l.fontSize, d.fontSize, reason: 'fontSize beda di #$i');
      expect(l.fontWeight, d.fontWeight, reason: 'fontWeight beda di #$i');
    }
  });

  test('InputDecorationTheme punya properti yang sama', () {
    final l = light.inputDecorationTheme;
    final d = dark.inputDecorationTheme;
    for (final pair in [
      (l.hintStyle, d.hintStyle),
      (l.labelStyle, d.labelStyle),
      (l.floatingLabelStyle, d.floatingLabelStyle),
      (l.errorStyle, d.errorStyle),
    ]) {
      expect(pair.$1, isNotNull);
      expect(pair.$2, isNotNull);
      expect(pair.$1!.fontSize, pair.$2!.fontSize);
      expect(pair.$1!.fontFamily, pair.$2!.fontFamily);
    }
    expect(l.contentPadding, d.contentPadding);
  });

  test('ThemeData.lerp light <-> dark tidak melempar', () {
    for (final t in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      expect(() => ThemeData.lerp(light, dark, t), returnsNormally);
    }
  });

  test('AppSurfaces.lerp mengisi semua field', () {
    final mid = AppSurfaces.light.lerp(AppSurfaces.dark, 0.5);
    // Kalau ada field yang lupa di-lerp, nilainya nyangkut di sisi light.
    expect(mid.surfaceAlt, isNot(AppSurfaces.light.surfaceAlt));
    expect(mid.textMuted, isNot(AppSurfaces.light.textMuted));
    expect(mid.warningTint, isNot(AppSurfaces.light.warningTint));
    expect(mid.onDangerTint, isNot(AppSurfaces.light.onDangerTint));
  });

  test('packageAccent stabil untuk nama yang sama', () {
    expect(
      AppTokens.packageAccent('Self Photo 15 Menit'),
      AppTokens.packageAccent('Self Photo 15 Menit'),
    );
    expect(
      AppTokens.packageAccents.contains(AppTokens.packageAccent('Wide Angle')),
      isTrue,
    );
  });

  test('dark mode tanpa bayangan, light mode dengan bayangan', () {
    expect(AppSurfaces.dark.cardShadow, isEmpty);
    expect(AppSurfaces.light.cardShadow, isNotEmpty);
  });
}
