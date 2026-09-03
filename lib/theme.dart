import 'package:flutter/material.dart';

class AppColors {
  static const forest = Color(0xFF1F3D2E);
  static const forestDark = Color(0xFF142A20);
  static const parchment = Color(0xFFF2ECD9);
  static const khaki = Color(0xFFA98F5E);
  static const khakiLight = Color(0xFFDCCFA8);
  static const ember = Color(0xFFC1440E);
  static const ink = Color(0xFF24261F);
  static const moss = Color(0xFF5C7A4A);
  static const mossLight = Color(0xFFE4EEDB);
  static const danger = Color(0xFFA32D2D);
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.parchment,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.forest,
      primary: AppColors.forest,
      secondary: AppColors.ember,
      surface: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.forest,
      foregroundColor: AppColors.parchment,
      elevation: 0,
      centerTitle: true,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.forestDark,
      selectedItemColor: Colors.white,
      unselectedItemColor: AppColors.khakiLight,
      type: BottomNavigationBarType.fixed,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.khakiLight),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.khakiLight),
      ),
    ),
    fontFamily: 'Roboto',
  );
}
