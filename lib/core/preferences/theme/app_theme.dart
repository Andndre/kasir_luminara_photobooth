import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/preferences/dimens.dart';
import 'package:luminara_photobooth/core/preferences/tokens.dart';

/// Satu builder untuk light dan dark.
///
/// Dulu ada dua kelas terpisah yang harus disamakan manual — properti yang
/// terlewat di salah satunya bikin crash "Failed to interpolate TextStyles"
/// saat ganti tema. Dengan satu builder, paritasnya dijamin oleh strukturnya.
ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final surfaces = isDark ? AppSurfaces.dark : AppSurfaces.light;

  final primary = isDark ? AppTokens.brand400 : AppTokens.brand600;
  // Krem (--cat-ground) di atas ivory (--cat-ivory) untuk light;
  // cokelat-tinta untuk dark.
  final bgBase = isDark ? const Color(0xFF14100F) : const Color(0xFFF7F3EC);
  final bgSurface = isDark ? const Color(0xFF1E1917) : const Color(0xFFFBF7F1);
  final textPrimary = isDark
      ? const Color(0xFFF7F3EC)
      : const Color(0xFF1A1412);

  // Brand web memakai Playfair Display (judul) + Instrument Sans (body).
  // Keduanya belum ter-bundle di aplikasi ini; Poppins dipertahankan supaya
  // build tetap jalan. Lihat DESIGN.md §3 untuk cara menukarnya.
  const family = 'Poppins';
  const tabular = <FontFeature>[FontFeature.tabularFigures()];

  final textTheme = TextTheme(
    // Nomor antrean di dialog sukses.
    displaySmall: TextStyle(
      fontSize: 40,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.0,
      color: textPrimary,
      fontFamily: family,
      fontFeatures: tabular,
    ),
    headlineLarge: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: textPrimary,
      fontFamily: family,
    ),
    headlineMedium: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
      color: textPrimary,
      fontFamily: family,
    ),
    headlineSmall: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      color: textPrimary,
      fontFamily: family,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      color: textPrimary,
      fontFamily: family,
    ),
    titleMedium: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: textPrimary,
      fontFamily: family,
    ),
    bodyLarge: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: textPrimary,
      fontFamily: family,
    ),
    bodyMedium: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: surfaces.textSecondary,
      fontFamily: family,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: surfaces.textMuted,
      fontFamily: family,
    ),
    labelLarge: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      color: textPrimary,
      fontFamily: family,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
      color: surfaces.textMuted,
      fontFamily: family,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
      color: surfaces.textMuted,
      fontFamily: family,
    ),
  );

  OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(Dimens.rMd),
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    brightness: brightness,
    useMaterial3: true,
    fontFamily: family,
    primaryColor: primary,
    scaffoldBackgroundColor: bgBase,
    canvasColor: bgBase,
    splashFactory: InkSparkle.splashFactory,
    extensions: [surfaces],

    colorScheme: ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: surfaces.brandTint,
      onPrimaryContainer: isDark ? AppTokens.brand300 : AppTokens.brand600,
      secondary: isDark ? AppTokens.accent500 : AppTokens.accent600,
      onSecondary: Colors.white,
      error: AppTokens.danger,
      onError: Colors.white,
      errorContainer: surfaces.dangerTint,
      onErrorContainer: surfaces.onDangerTint,
      surface: bgSurface,
      onSurface: textPrimary,
      surfaceContainerHighest: surfaces.surfaceAlt,
      onSurfaceVariant: surfaces.textSecondary,
      outline: surfaces.border,
      outlineVariant: surfaces.borderStrong,
    ),

    textTheme: textTheme,

    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: bgBase,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: textPrimary,
      titleTextStyle: textTheme.headlineMedium,
      iconTheme: IconThemeData(color: textPrimary, size: 22),
      actionsIconTheme: IconThemeData(color: textPrimary, size: 22),
    ),

    cardTheme: CardThemeData(
      elevation: 0,
      color: bgSurface,
      surfaceTintColor: Colors.transparent,
      shadowColor: surfaces.shadowColor,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dimens.rLg),
        side: BorderSide(color: surfaces.border),
      ),
    ),

    dividerTheme: DividerThemeData(
      color: surfaces.border,
      thickness: 1,
      space: 1,
    ),

    iconTheme: IconThemeData(color: textPrimary, size: 22),

    // Tombol pil (rounded-full), mengikuti CTA di web.
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: Dimens.dp24),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: surfaces.surfaceAlt,
        disabledForegroundColor: surfaces.textMuted,
        textStyle: textTheme.labelLarge,
        shape: const StadiumBorder(),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: Dimens.dp24),
        side: BorderSide(color: surfaces.borderStrong),
        foregroundColor: textPrimary,
        textStyle: textTheme.labelLarge,
        shape: const StadiumBorder(),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 44),
        foregroundColor: primary,
        textStyle: textTheme.labelLarge,
        shape: const StadiumBorder(),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: Dimens.dp24),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        textStyle: textTheme.labelLarge,
        shape: const StadiumBorder(),
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: const CircleBorder(),
    ),

    inputDecorationTheme: InputDecorationTheme(
      fillColor: surfaces.surfaceAlt,
      filled: true,
      iconColor: surfaces.textMuted,
      prefixIconColor: surfaces.textMuted,
      suffixIconColor: surfaces.textMuted,
      hintStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: surfaces.textMuted,
        fontFamily: family,
      ),
      labelStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: surfaces.textSecondary,
        fontFamily: family,
      ),
      floatingLabelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: primary,
        fontFamily: family,
      ),
      errorStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppTokens.danger,
        fontFamily: family,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Dimens.dp16,
        vertical: Dimens.dp16,
      ),
      enabledBorder: inputBorder(Colors.transparent),
      disabledBorder: inputBorder(Colors.transparent),
      focusedBorder: inputBorder(primary, 1.5),
      errorBorder: inputBorder(AppTokens.danger),
      focusedErrorBorder: inputBorder(AppTokens.danger, 1.5),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: surfaces.surfaceAlt,
      selectedColor: surfaces.brandTint,
      side: BorderSide.none,
      labelStyle: textTheme.labelLarge,
      secondaryLabelStyle: textTheme.labelLarge?.copyWith(color: primary),
      padding: const EdgeInsets.symmetric(horizontal: Dimens.dp12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dimens.rFull),
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: bgSurface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      indicatorColor: surfaces.brandTint,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dimens.rFull),
      ),
      height: 64,
      elevation: 0,
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? textTheme.labelSmall?.copyWith(color: primary, letterSpacing: 0.2)
            : textTheme.labelSmall?.copyWith(color: surfaces.textMuted),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 22,
          color: states.contains(WidgetState.selected)
              ? primary
              : surfaces.textMuted,
        ),
      ),
    ),

    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: bgSurface,
      indicatorColor: surfaces.brandTint,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dimens.rMd),
      ),
      selectedIconTheme: IconThemeData(color: primary, size: 24),
      unselectedIconTheme: IconThemeData(color: surfaces.textMuted, size: 22),
      selectedLabelTextStyle: textTheme.labelSmall?.copyWith(
        color: primary,
        letterSpacing: 0.2,
      ),
      unselectedLabelTextStyle: textTheme.labelSmall?.copyWith(
        color: surfaces.textMuted,
        fontWeight: FontWeight.w500,
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: bgSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyLarge,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dimens.rLg),
      ),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: bgSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Dimens.rXl)),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? surfaces.surfaceAlt : const Color(0xFF2A1F1C),
      contentTextStyle: textTheme.bodyLarge?.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dimens.rMd),
      ),
    ),

    listTileTheme: ListTileThemeData(
      iconColor: surfaces.textSecondary,
      titleTextStyle: textTheme.titleMedium,
      subtitleTextStyle: textTheme.bodyMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dimens.rMd),
      ),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? Colors.white : bgSurface,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? primary
            : surfaces.surfaceAlt,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.transparent
            : surfaces.borderStrong,
      ),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: primary,
      linearTrackColor: surfaces.surfaceAlt,
      circularTrackColor: surfaces.surfaceAlt,
    ),

    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primary
              : surfaces.surfaceAlt,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : surfaces.textSecondary,
        ),
        side: const WidgetStatePropertyAll(BorderSide.none),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Dimens.rMd),
          ),
        ),
      ),
    ),

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: isDark ? surfaces.surfaceAlt : const Color(0xFF2A1F1C),
        borderRadius: BorderRadius.circular(Dimens.rSm),
      ),
      textStyle: textTheme.bodySmall?.copyWith(color: Colors.white),
    ),
  );
}
