import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: const TextTheme(
        headlineSmall:
            TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.25),
        titleMedium:
            TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.35),
        bodyMedium: TextStyle(fontSize: 14, height: 1.5),
        bodySmall: TextStyle(fontSize: 12, height: 1.4),
      ),
      listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          minVerticalPadding: 8),
      dividerTheme: const DividerThemeData(color: Color(0xffe8e0d8), space: 24),
      cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xffe8e0d8)))),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 46),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)))),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16)),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
