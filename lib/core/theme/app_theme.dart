import 'package:flutter/material.dart';

/// Theme colors for MiamPlanning - Palette vert/bleu pastel
class AppColors {
  // Primary - Vert menthe doux
  static const primary = Color(0xFFB2DFDB);
  static const primaryMedium = Color(0xFF4DB6AC);
  static const primaryDark = Color(0xFF009688);

  // Secondary - Bleu ciel pastel
  static const secondary = Color(0xFFB3E5FC);
  static const secondaryMedium = Color(0xFF4FC3F7);
  static const secondaryDark = Color(0xFF03A9F4);

  // Accent colors
  static const sage = Color(0xFFC8E6C9);
  static const lavender = Color(0xFFD1C4E9);
  static const cream = Color(0xFFFFF8E1);
  static const peach = Color(0xFFFFE0B2);

  // Background - Blanc légèrement bleuté
  static const background = Color(0xFFF5FAFA);
  static const surface = Colors.white;
  static const surfaceVariant = Color(0xFFF0F7F7);

  // Text - Gris bleuté doux
  static const textPrimary = Color(0xFF37474F);
  static const textSecondary = Color(0xFF607D8B);
  static const textHint = Color(0xFF90A4AE);

  // Semantic - Versions pastel
  static const success = Color(0xFF81C784);
  static const warning = Color(0xFFFFD54F);
  static const error = Color(0xFFE57373);
  static const info = Color(0xFF64B5F6);

  // Nutrition colors - Pastel
  static const protein = Color(0xFFEF9A9A);
  static const vegetables = Color(0xFFA5D6A7);
  static const fruits = Color(0xFFFFE082);
  static const grains = Color(0xFFBCAAA4);
  static const dairy = Color(0xFF90CAF9);
}

/// App theme configuration
class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryMedium,
        brightness: Brightness.light,
        primary: AppColors.primaryMedium,
        secondary: AppColors.secondaryMedium,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        color: AppColors.surface,
        shadowColor: AppColors.primaryMedium.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryMedium,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          side: const BorderSide(color: AppColors.primaryMedium),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryMedium, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textHint),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: AppColors.primaryDark,
        unselectedItemColor: AppColors.textSecondary,
        backgroundColor: AppColors.surface,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryMedium,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.secondaryMedium;
          }
          return null;
        }),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primary,
        selectedColor: AppColors.primaryMedium,
        labelStyle: const TextStyle(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.surfaceVariant,
        thickness: 1,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  static ThemeData get dark {
    // Pour l'instant, on garde le thème light (app familiale = mode clair)
    return light;
  }
}
