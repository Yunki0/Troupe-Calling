import 'dart:io';
import 'package:flutter/material.dart';

/// Palette de branche : vert feuillage lumineux, vert profond et corail.
class AppColors {
  static const primary = Color(0xFF356B45);
  static const primaryDeep = Color(0xFF214630);
  static const canvas = Color(0xFFF3F8F1);
  static const canvasMuted = Color(0xFFE6F0E2);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceWarm = Color(0xFFFFFEFA);
  static const lagoon = Color(0xFF427F59);
  static const lagoonSoft = Color(0xFFDCEBDD);
  static const coral = Color(0xFFB94F36);
  static const coralSoft = Color(0xFFFBE8E1);
  static const text = Color(0xFF1F3024);
  static const textMuted = Color(0xFF526458);
  static const success = Color(0xFF2F6F4E);
  static const successSoft = Color(0xFFE1F0E5);
  static const warning = Color(0xFF8A5A13);
  static const warningSoft = Color(0xFFFFF0D1);
  static const danger = Color(0xFFB3261E);
  static const info = Color(0xFF376B4F);
  static const outline = Color(0xFFD7E2D4);
  static const shadow = Color(0xFF294B32);

  // Compatibilité avec les noms encore utilisés par les écrans existants.
  static const forest = primary;
  static const forestDark = primaryDeep;
  static const parchment = canvas;
  static const parchmentDeep = canvasMuted;
  static const khaki = lagoon;
  static const khakiLight = lagoonSoft;
  static const ember = coral;
  static const emberLight = Color(0xFFE18A70);
  static const ink = text;
  static const moss = success;
  static const mossLight = successSoft;
  static const gold = Color(0xFFD69A32);
}

class AppGradients {
  static const header = LinearGradient(
    colors: [AppColors.primary, AppColors.primaryDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const emberGlow = LinearGradient(
    colors: [AppColors.coral, Color(0xFF963C2A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const parchmentSoft = LinearGradient(
    colors: [AppColors.canvas, AppColors.canvasMuted],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class AppShadows {
  static const soft = [
    BoxShadow(color: Color(0x14294B32), blurRadius: 22, offset: Offset(0, 8)),
  ];

  static const card = [
    BoxShadow(color: Color(0x0D294B32), blurRadius: 14, offset: Offset(0, 4)),
  ];
}

/// Convertit un code couleur "#RRGGBB" (tel que stocké pour les
/// patrouilles) en [Color]. Utilisé à 4 endroits différents de l'appli
/// (roster, dashboard, fiche scout, patrouilles) : centralisé ici pour
/// éviter les divergences, et défensif car une valeur corrompue ou dans un
/// format inattendu ne doit jamais faire planter l'écran — elle retombe sur
/// [fallback].
Color patrouilleColorFromHex(String? hex, {Color fallback = AppColors.khaki}) {
  if (hex == null || hex.length != 7 || !hex.startsWith('#')) return fallback;
  final value = int.tryParse(hex.substring(1), radix: 16);
  if (value == null) return fallback;
  return Color(value + 0xFF000000);
}

/// Construit l'image de fond d'un avatar à partir d'un chemin de photo
/// local, ou `null` si aucune photo n'est renseignée OU si le fichier a
/// disparu du disque (stockage effacé par l'OS, chemin obsolète après une
/// réinstallation, etc.). Sans cette vérification, `FileImage` lève une
/// exception au moment du paint et l'avatar affiche une erreur au lieu du
/// repli "initiale du prénom" prévu par les écrans.
ImageProvider? avatarImageFor(String? photoPath) {
  if (photoPath == null) return null;
  if (!File(photoPath).existsSync()) return null;
  return FileImage(File(photoPath));
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.parchment,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.lagoon,
      onSecondary: Colors.white,
      tertiary: AppColors.coral,
      onTertiary: Colors.white,
      surface: AppColors.surfaceWarm,
      onSurface: AppColors.ink,
      error: AppColors.danger,
      onError: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 68,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surfaceWarm,
      indicatorColor: AppColors.mossLight,
      elevation: 0,
      height: 72,
      surfaceTintColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.forest, size: 23);
        }
        return IconThemeData(
          color: AppColors.ink.withValues(alpha: 0.64),
          size: 21,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color: selected
              ? AppColors.forest
              : AppColors.ink.withValues(alpha: 0.7),
          fontSize: 11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        );
      }),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.forest,
        side: const BorderSide(color: AppColors.outline),
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.coral,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surfaceWarm,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.outline),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.mossLight,
      labelStyle: const TextStyle(
        color: AppColors.forest,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.forest,
      textColor: AppColors.ink,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.outline,
      thickness: 1,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceWarm,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: const TextStyle(
        color: AppColors.forest,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surfaceWarm,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.forestDark,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFFFEFA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.forest, width: 1.6),
      ),
      labelStyle: const TextStyle(color: AppColors.ink),
    ),
    textTheme: Typography.material2021().black.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.forest,
      fontFamily: 'Roboto',
    ),
    fontFamily: 'Roboto',
  );
}
