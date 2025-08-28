import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Centralized color definitions
  static const Color primary = Color(0xFF6C9A8B); // Primary color
  static const Color secondary = Color(0xFFC1DADB); // Secondary color
  static const Color accent = Color(0xFFF4A261); // Accent color
  static const Color success = Color(0xFF2A9D8F); // Success color
  static const Color error = Color(0xFFE76F51); // Error color
  static const Color backgroundLight = Color(0xFFFDFCFB); // Light background
  static const Color backgroundDark = Color(0xFF0F172A); // Dark background
  static const Color surfaceLight = Color(0xFFFFFFFF); // Light surface
  static const Color surfaceDark = Color(0xFF1E293B); // Dark surface
  static const Color textPrimaryLight = Color(0xFF333333); // Text primary light
  static const Color textPrimaryDark = Color(0xFFFFFFFF); // Text primary dark
  static const Color textSecondaryLight = Color(0xFF757575); // Text secondary light
  static const Color textSecondaryDark = Color(0xFF94A3B8); // Text secondary dark

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: primary,
    scaffoldBackgroundColor: backgroundLight,
    colorScheme: const ColorScheme.light(
      primary: primary,
      secondary: secondary,
      surface: surfaceLight,
      onSurface: textPrimaryLight,
      error: error,
      onPrimary: textPrimaryDark,
      onSecondary: textPrimaryLight,
      surfaceVariant: secondary,
    ),
    textTheme: GoogleFonts.poppinsTextTheme().apply(
      bodyColor: textPrimaryLight,
      displayColor: textPrimaryLight,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: textPrimaryLight,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: textPrimaryDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textPrimaryLight,
        side: const BorderSide(color: secondary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    cardTheme: CardThemeData(
      color: surfaceLight,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: secondary.withOpacity(0.1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      labelStyle: const TextStyle(color: textSecondaryLight),
      prefixIconColor: accent,
    ),
    dividerColor: secondary.withOpacity(0.2),
    iconTheme: const IconThemeData(color: textPrimaryLight),
    dialogBackgroundColor: surfaceLight,
    shadowColor: Colors.black.withOpacity(0.2),
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primary,
    scaffoldBackgroundColor: backgroundDark,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: secondary,
      surface: surfaceDark,
      onSurface: textPrimaryDark,
      error: error,
      onPrimary: textPrimaryDark,
      onSecondary: textPrimaryDark,
      surfaceVariant: secondary,
    ),
    textTheme: GoogleFonts.poppinsTextTheme().apply(
      bodyColor: textPrimaryDark,
      displayColor: textPrimaryDark,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: textPrimaryDark,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: textPrimaryDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textPrimaryDark,
        side: BorderSide(color: secondary.withOpacity(0.2)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    cardTheme: CardThemeData(
      color: surfaceDark,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: secondary.withOpacity(0.1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      labelStyle: const TextStyle(color: textSecondaryDark),
      prefixIconColor: accent,
    ),
    dividerColor: secondary.withOpacity(0.2),
    iconTheme: const IconThemeData(color: textPrimaryDark),
    dialogBackgroundColor: surfaceDark,
    shadowColor: Colors.black.withOpacity(0.2),
  );
}