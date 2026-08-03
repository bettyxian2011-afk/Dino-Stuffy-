import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens and ThemeData for Strata.
abstract final class StrataColors {
  static const cream = Color(0xFFF7F4EF);
  static const orange = Color(0xFFF2994A);
  static const gold = Color(0xFFF2C94C);
  static const teal = Color(0xFF1B8E7D);
  static const confidence = Color(0xFF2A9D8F);
  static const brown = Color(0xFF8B5E3C);
  static const ink = Color(0xFF1A1510);
  static const muted = Color(0xFF6B6560);
  static const glass = Color(0x66000000);
  static const glassLight = Color(0x33FFFFFF);
}

abstract final class StrataRadii {
  static const card = 20.0;
  static const button = 28.0;
  static const pill = 999.0;
  static const icon = 16.0;
}

abstract final class StrataTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: StrataColors.cream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: StrataColors.orange,
        primary: StrataColors.orange,
        secondary: StrataColors.teal,
        surface: StrataColors.cream,
        brightness: Brightness.light,
      ),
    );

    final serif = GoogleFonts.libreBaskervilleTextTheme(base.textTheme);
    final sans = GoogleFonts.dmSansTextTheme(base.textTheme);

    return base.copyWith(
      textTheme: sans.copyWith(
        displayLarge: serif.displayLarge?.copyWith(
          color: StrataColors.ink,
          fontWeight: FontWeight.w700,
        ),
        displayMedium: serif.displayMedium?.copyWith(
          color: StrataColors.ink,
          fontWeight: FontWeight.w700,
        ),
        displaySmall: serif.displaySmall?.copyWith(
          color: StrataColors.ink,
          fontWeight: FontWeight.w700,
        ),
        headlineLarge: serif.headlineLarge?.copyWith(
          color: StrataColors.ink,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: serif.headlineMedium?.copyWith(
          color: StrataColors.ink,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: serif.headlineSmall?.copyWith(
          color: StrataColors.ink,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: serif.titleLarge?.copyWith(
          color: StrataColors.ink,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: StrataColors.cream,
        foregroundColor: StrataColors.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.libreBaskerville(
          color: StrataColors.ink,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
