import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import '../constants/app_constants.dart';

class AppTheme {
  // Border radius constants accesibles desde el theme
  static BorderRadius get cardBorderRadius   => BorderRadius.circular(AppConstants.cardBorderRadius);
  static BorderRadius get buttonBorderRadius => BorderRadius.circular(AppConstants.buttonBorderRadius);
  static BorderRadius get inputBorderRadius  => BorderRadius.circular(AppConstants.inputBorderRadius);
  /// Pastilla / pill (chips de filtro, search bar, avatar tags)
  static BorderRadius get pillBorderRadius   => BorderRadius.circular(20);
  /// Insignias pequeñas (badges de referencia, contadores)
  static BorderRadius get badgeBorderRadius  => BorderRadius.circular(6);
  
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: AppColors.primaryColor,
      scaffoldBackgroundColor: AppColors.backgroundLevel3,
      
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryColor,
        secondary: AppColors.secondaryColor,
        surface: AppColors.backgroundLevel1,
        surfaceContainer: AppColors.backgroundLevel2,
        onPrimary: AppColors.pureWhite,
        onSecondary: AppColors.pureWhite,
        onSurface: AppColors.textColor,
        error: AppColors.error,
        outline: AppColors.border,
      ),
      
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.pureWhite,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.quicksand(
          color: AppColors.pureWhite,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      
      cardTheme: CardThemeData(
        color: AppColors.backgroundLevel1,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: cardBorderRadius,
        ),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          foregroundColor: AppColors.pureWhite,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: buttonBorderRadius,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryColor,
          side: const BorderSide(color: AppColors.primaryColor),
          shape: RoundedRectangleBorder(
            borderRadius: buttonBorderRadius,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.backgroundLevel1,
        border: OutlineInputBorder(
          borderRadius: inputBorderRadius,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: inputBorderRadius,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: inputBorderRadius,
          borderSide: const BorderSide(color: AppColors.primaryColor, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.textColor2),
        hintStyle: const TextStyle(color: AppColors.textColor2),
      ),
      
      textTheme: GoogleFonts.quicksandTextTheme(
        const TextTheme(
          displayLarge: TextStyle(
            color: AppColors.textDark,
            fontSize: 32,
            fontWeight: FontWeight.w800,
          ),
          displayMedium: TextStyle(
            color: AppColors.textDark,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
          displaySmall: TextStyle(
            color: AppColors.textDark,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
          headlineLarge: TextStyle(
            color: AppColors.textDark,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          headlineMedium: TextStyle(
            color: AppColors.textDark,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          headlineSmall: TextStyle(
            color: AppColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          titleLarge: TextStyle(
            color: AppColors.textColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          titleMedium: TextStyle(
            color: AppColors.textColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          titleSmall: TextStyle(
            color: AppColors.textColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          bodyLarge: TextStyle(
            color: AppColors.textColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          bodyMedium: TextStyle(
            color: AppColors.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          bodySmall: TextStyle(
            color: AppColors.textColor2,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          labelSmall: TextStyle(
            color: AppColors.textColor2,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.backgroundLevel2,
        selectedColor: AppColors.secondaryColor,
        labelStyle: const TextStyle(color: AppColors.textColor, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
