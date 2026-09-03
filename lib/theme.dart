import 'package:flutter/material.dart';

/// Palette de l'app. Les noms existants sont conservés pour ne rien casser
/// ailleurs dans le code ; les teintes ont été légèrement affinées (plus de
/// contraste, moins "ternes") et quelques tokens ont été ajoutés.
class AppColors {
  static const forest = Color(0xFF1E3D2B);
  static const forestDark = Color(0xFF11251A);
  static const parchment = Color(0xFFF4EFE1);
  static const parchmentDeep = Color(0xFFEAE1C8); // pour les fonds de section
  static const khaki = Color(0xFFAD9159);
  static const khakiLight = Color(0xFFE1D3AC);
  static const ember = Color(0xFFC24A16);
  static const emberLight = Color(0xFFE68A5C);
  static const ink = Color(0xFF23261E);
  static const moss = Color(0xFF4F7A45);
  static const mossLight = Color(0xFFE2EFDA);
  static const danger = Color(0xFFA22F2F);
  static const gold = Color(0xFFC79A3D); // accent CP / mise en valeur
  static const info = Color(0xFF2E5C6E); // stats / infos neutres
  static const shadow = Color(0xFF11251A);
}

class AppGradients {
  static const header = LinearGradient(
    colors: [AppColors.forest, AppColors.forestDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const emberGlow = LinearGradient(
    colors: [AppColors.ember, Color(0xFFA33A10)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const parchmentSoft = LinearGradient(
    colors: [AppColors.parchment, AppColors.parchmentDeep],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class AppShadows {
  static List<BoxShadow> soft = [
    BoxShadow(
      color: AppColors.shadow.withValues(alpha: 0.12),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> card = [
    BoxShadow(
      color: AppColors.shadow.withValues(alpha: 0.06),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ];
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
      error: AppColors.danger,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.forest,
      foregroundColor: AppColors.parchment,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: AppColors.parchment,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.forestDark,
      selectedItemColor: Colors.white,
      unselectedItemColor: AppColors.khakiLight,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5),
      unselectedLabelStyle: TextStyle(fontSize: 11),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.forest,
        side: const BorderSide(color: AppColors.forest),
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.ember,
      foregroundColor: Colors.white,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.khakiLight),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.mossLight,
      labelStyle: const TextStyle(color: AppColors.forest, fontWeight: FontWeight.w600, fontSize: 12),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.forest,
      textColor: AppColors.ink,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.khakiLight, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.forestDark,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.khakiLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.forest, width: 1.6),
      ),
      labelStyle: const TextStyle(color: AppColors.ink),
    ),
    fontFamily: 'Roboto',
  );
}
