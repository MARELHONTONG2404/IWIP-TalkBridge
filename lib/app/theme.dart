import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
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
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Color(0xFF1F2937),
    ),

    textTheme: GoogleFonts.nunitoTextTheme().copyWith(
      headlineMedium: GoogleFonts.nunito(
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
      ),
      titleLarge: GoogleFonts.nunito(fontWeight: FontWeight.w800),
      titleMedium: GoogleFonts.nunito(fontWeight: FontWeight.w700),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.violet,
      brightness: Brightness.dark,
    ),

    textTheme: GoogleFonts.nunitoTextTheme(ThemeData.dark().textTheme),
  );
}
