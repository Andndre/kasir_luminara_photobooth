import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/core.dart';

class LightTheme {
  final Color primaryColor;
  final Color errorColor = AppColors.red;
  // Use direct values or safe access
  final Color scaffoldColor = const Color(0xffFAFAFA); // AppColors.white[200]
  final Color textSolidColor = AppColors.black;
  final Color borderColor = AppColors.white;
  final Color textDisabledColor = AppColors.textDisabled;
  final Color inputColor = const Color(0xffFAFAFA); // AppColors.white[200]

  TextTheme get textTheme => TextTheme(
    headlineLarge: TextStyle(
      fontSize: Dimens.dp32,
      fontWeight: FontWeight.bold,
      color: textSolidColor,
      fontFamily: 'Poppins',
    ),
    headlineMedium: TextStyle(
      fontSize: Dimens.dp24,
      fontWeight: FontWeight.w600,
      color: textSolidColor,
      fontFamily: 'Poppins',
    ),
    headlineSmall: TextStyle(
      fontSize: Dimens.dp20,
      fontWeight: FontWeight.w600,
      color: textSolidColor,
      fontFamily: 'Poppins',
    ),
    titleLarge: TextStyle(
      fontSize: Dimens.dp16,
      fontWeight: FontWeight.w600,
      color: textSolidColor,
      fontFamily: 'Poppins',
    ),
    titleMedium: TextStyle(
      fontSize: Dimens.dp14,
      fontWeight: FontWeight.w600,
      color: textSolidColor,
      fontFamily: 'Poppins',
    ),
    bodyLarge: TextStyle(
      fontSize: Dimens.dp16,
      fontWeight: FontWeight.w500,
      color: textSolidColor,
      fontFamily: 'Poppins',
    ),
    bodyMedium: TextStyle(
      fontSize: Dimens.dp14,
      fontWeight: FontWeight.normal,
      color: textSolidColor,
      fontFamily: 'Poppins',
    ),
    labelMedium: TextStyle(
      fontSize: Dimens.dp12,
      fontWeight: FontWeight.w500,
      color: textDisabledColor,
      fontFamily: 'Poppins',
    ),
  );

  LightTheme(this.primaryColor);

  CardThemeData get cardTheme => CardThemeData(
    elevation: 0,
    color: Colors.white,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Dimens.radius),
      side: BorderSide(color: borderColor),
    ),
  );

  AppBarTheme get appBarTheme => AppBarTheme(
    centerTitle: false,
    surfaceTintColor: scaffoldColor,
    shadowColor: Colors.black.withAlpha((0.4 * 255).round()),
  );

  BottomNavigationBarThemeData get bottomNavigationBarTheme {
    return BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: primaryColor,
      selectedLabelStyle: textTheme.labelMedium?.copyWith(
        fontSize: Dimens.dp10,
        color: primaryColor,
      ),
      unselectedLabelStyle: textTheme.labelMedium?.copyWith(
        fontSize: Dimens.dp10,
        color: textDisabledColor,
      ),
    );
  }

  ElevatedButtonThemeData get elevatedButtonTheme {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimens.radius),
        ),
        backgroundColor: primaryColor,
        foregroundColor: scaffoldColor,
        textStyle: textTheme.titleMedium,
      ),
    );
  }

  OutlinedButtonThemeData get outlinedButtonTheme {
    return OutlinedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimens.radius),
        ),
        side: BorderSide(color: primaryColor),
        foregroundColor: primaryColor,
        textStyle: textTheme.titleMedium,
      ),
    );
  }

  InputDecorationTheme get inputDecorationTheme {
    return InputDecorationTheme(
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
        horizontal: Dimens.defaultSize,
        vertical: Dimens.dp12,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Dimens.radius),
        borderSide: BorderSide(color: inputColor),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Dimens.radius),
        borderSide: BorderSide(color: inputColor),
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
    );
  }

  DividerThemeData get dividerTheme {
    return DividerThemeData(
      color: Colors.grey.withValues(alpha: 0.2),
      thickness: 1,
      space: 1,
    );
  }

  ThemeData get theme {
    return ThemeData(
      primaryColor: primaryColor,
      fontFamily: 'Poppins',
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: primaryColor,
        error: errorColor,
      ),
      scaffoldBackgroundColor: scaffoldColor,
      useMaterial3: true,
      textTheme: textTheme,
      appBarTheme: appBarTheme,
      cardTheme: cardTheme,
      bottomNavigationBarTheme: bottomNavigationBarTheme,
      elevatedButtonTheme: elevatedButtonTheme,
      outlinedButtonTheme: outlinedButtonTheme,
      inputDecorationTheme: inputDecorationTheme,
      dividerTheme: dividerTheme,
    );
  }
}
