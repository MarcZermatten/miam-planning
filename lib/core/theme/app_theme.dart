import 'package:flutter/material.dart';

/// Extension to get theme-aware colors from BuildContext
extension ThemeColors on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get colorBackground => isDarkMode ? AppColors.darkBackground : AppColors.background;
  Color get colorSurface => isDarkMode ? AppColors.darkSurface : AppColors.surface;
  Color get colorSurfaceVariant => isDarkMode ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant;
  Color get colorTextPrimary => isDarkMode ? AppColors.darkTextPrimary : AppColors.textPrimary;
  Color get colorTextSecondary => isDarkMode ? AppColors.darkTextSecondary : AppColors.textSecondary;
  Color get colorTextHint => isDarkMode ? AppColors.darkTextHint : AppColors.textHint;
  Color get colorPrimary => isDarkMode ? AppColors.darkPrimary : AppColors.primaryMedium;
  Color get colorPrimaryDark => isDarkMode ? AppColors.darkPrimaryDark : AppColors.primaryDark;
  Color get colorSecondary => isDarkMode ? AppColors.darkSecondary : AppColors.secondaryMedium;
}

/// Theme colors for MiamPlanning - Palette vert/bleu pastel
class AppColors {
  // === MODE CLAIR ===

  // Primary - Vert menthe
  static const primary = Color(0xFFB2DFDB);        // Fond clair
  static const primaryMedium = Color(0xFF4DB6AC); // Boutons, accents
  static const primaryDark = Color(0xFF00796B);   // Texte sur fond clair (amélioré)

  // Secondary - Bleu
  static const secondary = Color(0xFFB3E5FC);      // Fond clair
  static const secondaryMedium = Color(0xFF4FC3F7); // Accents
  static const secondaryDark = Color(0xFF0277BD);  // Texte sur fond clair (amélioré)

  // Accent colors (fonds uniquement)
  static const sage = Color(0xFFC8E6C9);
  static const lavender = Color(0xFFD1C4E9);
  static const cream = Color(0xFFFFF8E1);
  static const peach = Color(0xFFFFE0B2);

  // Background - Mode clair
  static const background = Color(0xFFF5FAFA);
  static const surface = Colors.white;
  static const surfaceVariant = Color(0xFFF0F7F7);

  // Text - Mode clair (contrastes améliorés)
  static const textPrimary = Color(0xFF1A252A);   // Plus foncé pour meilleur contraste
  static const textSecondary = Color(0xFF455A64); // Plus foncé
  static const textHint = Color(0xFF78909C);      // Légèrement plus foncé

  // Semantic - Versions plus saturées pour meilleur contraste
  static const success = Color(0xFF43A047);       // Plus foncé
  static const successLight = Color(0xFFC8E6C9); // Version fond
  static const warning = Color(0xFFFFA000);       // Plus foncé
  static const warningLight = Color(0xFFFFF3E0); // Version fond
  static const error = Color(0xFFE53935);         // Plus foncé
  static const errorLight = Color(0xFFFFEBEE);   // Version fond
  static const info = Color(0xFF1E88E5);          // Plus foncé
  static const infoLight = Color(0xFFE3F2FD);    // Version fond

  // Nutrition colors - Pastel (fonds uniquement)
  static const protein = Color(0xFFEF9A9A);
  static const vegetables = Color(0xFFA5D6A7);
  static const fruits = Color(0xFFFFE082);
  static const grains = Color(0xFFBCAAA4);
  static const dairy = Color(0xFF90CAF9);

  // === MODE SOMBRE ===

  static const darkBackground = Color(0xFF121212);
  static const darkSurface = Color(0xFF1E1E1E);
  static const darkSurfaceVariant = Color(0xFF2C2C2C);
  static const darkTextPrimary = Color(0xFFE0E0E0);
  static const darkTextSecondary = Color(0xFFB0B0B0);
  static const darkTextHint = Color(0xFF808080);
  static const darkPrimary = Color(0xFF80CBC4);      // Vert menthe lumineux
  static const darkPrimaryDark = Color(0xFF4DB6AC);
  static const darkSecondary = Color(0xFF81D4FA);    // Bleu lumineux
  static const darkSecondaryDark = Color(0xFF4FC3F7);
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
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.darkPrimary,
        brightness: Brightness.dark,
        primary: AppColors.darkPrimary,
        secondary: AppColors.darkSecondary,
        surface: AppColors.darkSurface,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkTextPrimary,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: AppColors.darkSurface,
        shadowColor: Colors.black45,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkPrimaryDark,
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
          foregroundColor: AppColors.darkPrimary,
          side: const BorderSide(color: AppColors.darkPrimary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.darkPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceVariant,
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
          borderSide: const BorderSide(color: AppColors.darkPrimary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: AppColors.darkTextSecondary),
        hintStyle: const TextStyle(color: AppColors.darkTextHint),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: AppColors.darkPrimary,
        unselectedItemColor: AppColors.darkTextSecondary,
        backgroundColor: AppColors.darkSurface,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.darkPrimaryDark,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.darkSecondary;
          }
          return null;
        }),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurfaceVariant,
        selectedColor: AppColors.darkPrimaryDark,
        labelStyle: const TextStyle(color: AppColors.darkTextPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkSurfaceVariant,
        thickness: 1,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        textColor: AppColors.darkTextPrimary,
        iconColor: AppColors.darkTextSecondary,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.darkTextSecondary,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.darkTextPrimary),
        bodyMedium: TextStyle(color: AppColors.darkTextPrimary),
        bodySmall: TextStyle(color: AppColors.darkTextSecondary),
        titleLarge: TextStyle(color: AppColors.darkTextPrimary),
        titleMedium: TextStyle(color: AppColors.darkTextPrimary),
        titleSmall: TextStyle(color: AppColors.darkTextSecondary),
        labelLarge: TextStyle(color: AppColors.darkTextPrimary),
        labelMedium: TextStyle(color: AppColors.darkTextSecondary),
        labelSmall: TextStyle(color: AppColors.darkTextHint),
      ),
    );
  }
}
