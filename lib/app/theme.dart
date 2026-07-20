import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.backgroundTop,

    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.coral,
      primary: AppColors.coral,
      secondary: AppColors.sky,
      tertiary: AppColors.sunny,
      brightness: Brightness.light,
    ),

    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: AppColors.backgroundTop,
      foregroundColor: Color(0xFF1F2937),
      titleTextStyle: TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.25,
      ),
    ),

    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 1,
      shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.08),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),

    textTheme: GoogleFonts.nunitoTextTheme().copyWith(
      headlineMedium: GoogleFonts.nunito(
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
      ),
      titleLarge: GoogleFonts.nunito(fontWeight: FontWeight.w800),
      titleMedium: GoogleFonts.nunito(fontWeight: FontWeight.w700),
      bodyLarge: GoogleFonts.nunito(fontSize: 16, height: 1.45),
      bodyMedium: GoogleFonts.nunito(fontSize: 14, height: 1.4),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0F172A),

    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.violet,
      brightness: Brightness.dark,
    ),

    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Color(0xFF0F172A),
      foregroundColor: Color(0xFFF8FAFC),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF172033),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    textTheme: GoogleFonts.nunitoTextTheme(ThemeData.dark().textTheme).copyWith(
      headlineMedium: GoogleFonts.nunito(fontWeight: FontWeight.w900),
      titleLarge: GoogleFonts.nunito(fontWeight: FontWeight.w800),
      titleMedium: GoogleFonts.nunito(fontWeight: FontWeight.w700),
      bodyLarge: GoogleFonts.nunito(fontSize: 16, height: 1.45),
      bodyMedium: GoogleFonts.nunito(fontSize: 14, height: 1.4),
    ),
  );
}
