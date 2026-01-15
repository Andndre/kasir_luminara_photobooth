import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/core.dart';

class DarkTheme {
  final Color primaryColor;
  final Color errorColor = AppColors.red;
  final Color scaffoldColor = const Color(0xFF1A1A1A);
  final Color cardColor = const Color(0xFF2D2D2D);
  final Color textSolidColor = Colors.white;
  final Color borderColor = const Color(0xFF3D3D3D);
  final Color textDisabledColor = Colors.white54;
  final Color inputColor = const Color(0xFF333333);

  DarkTheme(this.primaryColor);

  TextTheme get textTheme => TextTheme(
    headlineLarge: TextStyle(fontSize: Dimens.dp32, fontWeight: FontWeight.bold, color: textSolidColor, fontFamily: 'Poppins'),
    headlineMedium: TextStyle(fontSize: Dimens.dp24, fontWeight: FontWeight.w600, color: textSolidColor, fontFamily: 'Poppins'),
    headlineSmall: TextStyle(fontSize: Dimens.dp20, fontWeight: FontWeight.w600, color: textSolidColor, fontFamily: 'Poppins'),
    titleLarge: TextStyle(fontSize: Dimens.dp16, fontWeight: FontWeight.w600, color: textSolidColor, fontFamily: 'Poppins'),
    titleMedium: TextStyle(fontSize: Dimens.dp14, fontWeight: FontWeight.w600, color: textSolidColor, fontFamily: 'Poppins'),
    bodyLarge: TextStyle(fontSize: Dimens.dp16, fontWeight: FontWeight.w500, color: textSolidColor, fontFamily: 'Poppins'),
    bodyMedium: TextStyle(fontSize: Dimens.dp14, fontWeight: FontWeight.normal, color: textSolidColor, fontFamily: 'Poppins'),
    labelMedium: TextStyle(fontSize: Dimens.dp12, fontWeight: FontWeight.w500, color: textDisabledColor, fontFamily: 'Poppins'),
  );

  ThemeData get theme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      fontFamily: 'Poppins',
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: primaryColor,
        error: errorColor,
        surface: cardColor,
        onSurface: textSolidColor,
      ),
      scaffoldBackgroundColor: scaffoldColor,
      useMaterial3: true,
      textTheme: textTheme,
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardColor,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimens.radius),
          side: BorderSide(color: borderColor),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scaffoldColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textSolidColor,
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: inputColor,
        filled: true,
        iconColor: textDisabledColor,
        hintStyle: TextStyle(
          fontSize: Dimens.dp12,
          fontWeight: FontWeight.w500,
          color: textDisabledColor,
          fontFamily: 'Poppins',
        ),
        labelStyle: TextStyle(
          fontSize: Dimens.dp14,
          fontWeight: FontWeight.normal,
          color: textSolidColor,
          fontFamily: 'Poppins',
        ),
        floatingLabelStyle: TextStyle(
          fontSize: Dimens.dp12,
          fontWeight: FontWeight.w500,
          color: primaryColor,
          fontFamily: 'Poppins',
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: Dimens.defaultSize, vertical: Dimens.dp12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Dimens.radius),
          borderSide: BorderSide(color: borderColor),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Dimens.radius),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Dimens.radius),
          borderSide: BorderSide(color: primaryColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Dimens.radius),
          borderSide: BorderSide(color: errorColor),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Dimens.radius),
          borderSide: BorderSide(color: errorColor),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scaffoldColor,
        selectedIconTheme: const IconThemeData(color: Colors.white),
        unselectedIconTheme: IconThemeData(color: textDisabledColor),
        selectedLabelTextStyle: TextStyle(color: textSolidColor),
        unselectedLabelTextStyle: TextStyle(color: textDisabledColor),
        indicatorColor: primaryColor,
      ),
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Dimens.radius),
          ),
          backgroundColor: primaryColor,
          foregroundColor: textSolidColor,
          textStyle: textTheme.titleMedium,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Dimens.radius),
          ),
          side: BorderSide(color: primaryColor),
          foregroundColor: primaryColor,
          textStyle: textTheme.titleMedium,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: primaryColor,
        selectedLabelStyle: textTheme.labelMedium?.copyWith(
          fontSize: Dimens.dp10,
          color: primaryColor,
          fontFamily: 'Poppins',
        ),
        unselectedLabelStyle: textTheme.labelMedium?.copyWith(
          fontSize: Dimens.dp10,
          color: textDisabledColor,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }
}
