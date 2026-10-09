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

  static const darkCanvas = Color(0xFF141B16);
  static const darkSurface = Color(0xFF1C2720);
  static const darkSurfaceWarm = Color(0xFF243229);
  static const darkPrimary = Color(0xFFA6D391);
  static const darkPrimaryDeep = Color(0xFF294633);
  static const darkSecondary = Color(0xFFC4D5BD);
  static const darkCoral = Color(0xFFF1A18A);
  static const darkText = Color(0xFFE7EEE7);
  static const darkTextMuted = Color(0xFFB2C0B4);
  static const darkOutline = Color(0xFF405346);
  static const darkSoftGreen = Color(0xFF304435);
  static const darkSoftCoral = Color(0xFF432F29);
  static const darkSuccess = Color(0xFF9BD0A7);
  static const darkWarning = Color(0xFFFFD18A);
  static const darkDanger = Color(0xFFFFB4AB);
}

class AppPalette {
  const AppPalette._({
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.inputSurface,
    required this.primary,
    required this.primaryDeep,
    required this.secondary,
    required this.secondarySoft,
    required this.onSecondarySoft,
    required this.onBrand,
    required this.accent,
    required this.accentSoft,
    required this.text,
    required this.textMuted,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.outline,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceRaised;
  final Color inputSurface;
  final Color primary;
  final Color primaryDeep;
  final Color secondary;
  final Color secondarySoft;
  final Color onSecondarySoft;
  final Color onBrand;
  final Color accent;
  final Color accentSoft;
  final Color text;
  final Color textMuted;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color outline;

  static const light = AppPalette._(
    canvas: AppColors.canvas,
    surface: AppColors.surface,
    surfaceRaised: AppColors.surfaceWarm,
    inputSurface: AppColors.surfaceWarm,
    primary: AppColors.primary,
    primaryDeep: AppColors.primaryDeep,
    secondary: AppColors.lagoon,
    secondarySoft: AppColors.lagoonSoft,
    onSecondarySoft: AppColors.primaryDeep,
    onBrand: AppColors.lagoonSoft,
    accent: AppColors.coral,
    accentSoft: AppColors.coralSoft,
    text: AppColors.text,
    textMuted: AppColors.textMuted,
    success: AppColors.success,
    successSoft: AppColors.successSoft,
    warning: AppColors.warning,
    warningSoft: AppColors.warningSoft,
    danger: AppColors.danger,
    outline: AppColors.outline,
  );

  static const dark = AppPalette._(
    canvas: AppColors.darkCanvas,
    surface: AppColors.darkSurface,
    surfaceRaised: AppColors.darkSurfaceWarm,
    inputSurface: Color(0xFF202C24),
    primary: AppColors.darkPrimary,
    primaryDeep: AppColors.darkPrimaryDeep,
    secondary: AppColors.darkSecondary,
    secondarySoft: AppColors.darkSoftGreen,
    onSecondarySoft: AppColors.darkText,
    onBrand: AppColors.darkSecondary,
    accent: AppColors.darkCoral,
    accentSoft: AppColors.darkSoftCoral,
    text: AppColors.darkText,
    textMuted: AppColors.darkTextMuted,
    success: AppColors.darkSuccess,
    successSoft: AppColors.darkSoftGreen,
    warning: AppColors.darkWarning,
    warningSoft: Color(0xFF403724),
    danger: AppColors.darkDanger,
    outline: AppColors.darkOutline,
  );

  static AppPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

class AppGradients {
  static const header = LinearGradient(
    colors: [AppColors.primary, AppColors.primaryDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const headerDark = LinearGradient(
    colors: [Color(0xFF294633), Color(0xFF1D3024)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient headerFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? headerDark : header;

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

ThemeData buildAppDarkTheme() {
  const colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.darkPrimary,
    onPrimary: AppColors.darkCanvas,
    primaryContainer: AppColors.darkPrimaryDeep,
    onPrimaryContainer: AppColors.darkText,
    secondary: AppColors.darkSecondary,
    onSecondary: AppColors.darkCanvas,
    secondaryContainer: AppColors.darkSoftGreen,
    onSecondaryContainer: AppColors.darkText,
    tertiary: AppColors.darkCoral,
    onTertiary: AppColors.darkCanvas,
    error: AppColors.darkDanger,
    onError: Color(0xFF690005),
    surface: AppColors.darkCanvas,
    onSurface: AppColors.darkText,
    surfaceContainerLowest: AppColors.darkCanvas,
    surfaceContainerLow: AppColors.darkSurface,
    surfaceContainer: AppColors.darkSurface,
    surfaceContainerHigh: AppColors.darkSurfaceWarm,
    surfaceContainerHighest: Color(0xFF2B3A30),
    onSurfaceVariant: AppColors.darkTextMuted,
    outline: AppColors.darkOutline,
    outlineVariant: Color(0xFF344238),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: AppColors.darkText,
    onInverseSurface: AppColors.darkCanvas,
    inversePrimary: AppColors.primary,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.darkCanvas,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkPrimaryDeep,
      foregroundColor: AppColors.darkText,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 68,
      titleTextStyle: TextStyle(
        color: AppColors.darkText,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.darkSurface,
      indicatorColor: AppColors.darkSoftGreen,
      elevation: 0,
      height: 72,
      surfaceTintColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.darkPrimary
              : AppColors.darkTextMuted,
          size: states.contains(WidgetState.selected) ? 23 : 21,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          color: states.contains(WidgetState.selected)
              ? AppColors.darkPrimary
              : AppColors.darkTextMuted,
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        );
      }),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.darkPrimaryDeep,
        foregroundColor: AppColors.darkText,
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.darkPrimary,
        foregroundColor: AppColors.darkCanvas,
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.darkPrimary,
        side: const BorderSide(color: AppColors.darkOutline),
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.darkCoral,
      foregroundColor: AppColors.darkCanvas,
    ),
    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.darkOutline),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.darkSoftGreen,
      labelStyle: const TextStyle(
        color: AppColors.darkText,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.darkPrimary,
      textColor: AppColors.darkText,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.darkOutline,
      thickness: 1,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.darkSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: const TextStyle(
        color: AppColors.darkText,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.darkSurface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.darkSurfaceWarm,
      contentTextStyle: const TextStyle(color: AppColors.darkText),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF202C24),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.darkOutline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.darkOutline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.darkPrimary, width: 1.6),
      ),
      labelStyle: const TextStyle(color: AppColors.darkTextMuted),
    ),
    textTheme: Typography.material2021().white.apply(
      bodyColor: AppColors.darkText,
      displayColor: AppColors.darkPrimary,
      fontFamily: 'Roboto',
    ),
    fontFamily: 'Roboto',
  );
}
