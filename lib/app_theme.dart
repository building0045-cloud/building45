import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const background = Color(0xFFF4F5F7);
  static const surface = Colors.white;
  static const ink = Color(0xFF15171C);
  static const inkSoft = Color(0xFF2B2F38);
  static const accent = Color(0xFFD4F36B);
  static const muted = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
}

/// Light theme: soft grey page, white rounded cards, dark ink buttons and a
/// lime accent.
ThemeData buildAppTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.ink,
        brightness: Brightness.light,
      ).copyWith(
        primary: AppColors.ink,
        onPrimary: Colors.white,
        secondary: AppColors.accent,
        onSecondary: AppColors.ink,
        secondaryContainer: AppColors.accent,
        onSecondaryContainer: AppColors.ink,
        primaryContainer: AppColors.accent,
        onPrimaryContainer: AppColors.ink,
        surface: AppColors.surface,
        surfaceContainerHighest: const Color(0xFFEDEEF1),
        onSurfaceVariant: AppColors.muted,
        outline: const Color(0xFF9CA3AF),
        outlineVariant: AppColors.border,
      );
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
  );
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      centerTitle: true,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.ink, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: rounded,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: rounded,
        foregroundColor: AppColors.ink,
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: const StadiumBorder(side: BorderSide(color: AppColors.border)),
      selectedColor: AppColors.accent,
      backgroundColor: AppColors.surface,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.accent,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStatePropertyAll(base.textTheme.labelMedium),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.accent,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.ink,
      foregroundColor: Colors.white,
    ),
    listTileTheme: const ListTileThemeData(iconColor: AppColors.ink),
    dividerTheme: const DividerThemeData(color: AppColors.border),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
