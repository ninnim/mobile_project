import 'package:flutter/material.dart';
import 'app_colors.dart';

ThemeData buildDarkTheme(Color accent) {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: DarkColors.background,
    primaryColor: accent,
    colorScheme: ColorScheme.dark(
      primary: accent,
      secondary: DarkColors.secondary,
      surface: DarkColors.surface,
      error: DarkColors.error,
      onPrimary: DarkColors.background,
      onSurface: DarkColors.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: DarkColors.background,
      foregroundColor: DarkColors.text,
      elevation: 0,
      centerTitle: true,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: DarkColors.text, fontSize: 28, fontWeight: FontWeight.w800),
      headlineMedium: TextStyle(color: DarkColors.text, fontSize: 22, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(color: DarkColors.text, fontSize: 18, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: DarkColors.text, fontSize: 16),
      bodyMedium: TextStyle(color: DarkColors.textSecondary, fontSize: 14),
      labelSmall: TextStyle(color: DarkColors.textSecondary, fontSize: 12),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0x801A1D3D),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0x4DA0A3BD)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0x4DA0A3BD)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
      hintStyle: const TextStyle(color: DarkColors.textSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    useMaterial3: true,
  );
}

ThemeData buildLightTheme(Color accent) {
  return ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: LightColors.background,
    primaryColor: accent,
    colorScheme: ColorScheme.light(
      primary: accent,
      secondary: LightColors.secondary,
      surface: LightColors.surface,
      error: LightColors.error,
      onPrimary: Colors.white,
      onSurface: LightColors.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: LightColors.background,
      foregroundColor: LightColors.text,
      elevation: 0,
      centerTitle: true,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: LightColors.text, fontSize: 28, fontWeight: FontWeight.w800),
      headlineMedium: TextStyle(color: LightColors.text, fontSize: 22, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(color: LightColors.text, fontSize: 18, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: LightColors.text, fontSize: 16),
      bodyMedium: TextStyle(color: LightColors.textSecondary, fontSize: 14),
      labelSmall: TextStyle(color: LightColors.textSecondary, fontSize: 12),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: LightColors.cardGlass,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: LightColors.borderGlow),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0x4D5C5F7A)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
      hintStyle: const TextStyle(color: LightColors.textSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    useMaterial3: true,
  );
}
