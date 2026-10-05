import 'package:flutter/material.dart';

abstract final class FixiaColors {
  static const primary = Color(0xFF01255D);
  static const secondary = Color(0xFF006DFD);
  static const accent = Color(0xFF00B79E);
  static const supportBackground = Color(0xFFDCEBFF);
  static const textPrimary = Color(0xFF0B1220);
  static const textSecondary = Color(0xFF5B6B7C);
  static const background = Color(0xFFF4F7FB);
  static const white = Color(0xFFFFFFFF);
}

abstract final class FixiaRadii {
  static const input = 14.0;
  static const consent = 16.0;
  static const card = 24.0;
}

abstract final class FixiaTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.light(
      primary: FixiaColors.primary,
      onPrimary: FixiaColors.white,
      secondary: FixiaColors.secondary,
      onSecondary: FixiaColors.white,
      tertiary: FixiaColors.accent,
      onTertiary: FixiaColors.primary,
      surface: FixiaColors.white,
      onSurface: FixiaColors.primary,
      onSurfaceVariant: FixiaColors.textSecondary,
      surfaceContainerLowest: FixiaColors.white,
      surfaceContainerLow: FixiaColors.background,
      surfaceContainer: FixiaColors.supportBackground,
      outline: FixiaColors.textSecondary,
      outlineVariant: FixiaColors.supportBackground,
    );
    final textTheme = ThemeData.light().textTheme.apply(
      fontFamily: 'Inter',
      bodyColor: FixiaColors.primary,
      displayColor: FixiaColors.primary,
    );

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: FixiaColors.background,
      fontFamily: 'Inter',
      textTheme: textTheme.copyWith(
        headlineSmall: textTheme.headlineSmall?.copyWith(
          color: FixiaColors.primary,
          fontWeight: FontWeight.w700,
          fontVariations: const [FontVariation('wght', 700)],
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          color: FixiaColors.primary,
          fontWeight: FontWeight.w600,
          fontVariations: const [FontVariation('wght', 600)],
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          fontVariations: const [FontVariation('wght', 600)],
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: FixiaColors.background,
        foregroundColor: FixiaColors.primary,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FixiaColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FixiaRadii.input),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FixiaRadii.input),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FixiaRadii.input),
          borderSide: const BorderSide(
            color: FixiaColors.secondary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FixiaRadii.input),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FixiaRadii.input),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
        labelStyle: const TextStyle(color: FixiaColors.textSecondary),
        floatingLabelStyle: const TextStyle(color: FixiaColors.secondary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.secondary,
          foregroundColor: colorScheme.onSecondary,
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          elevation: 2,
          shadowColor: FixiaColors.primary.withValues(alpha: 0.16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FixiaRadii.input),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.secondary;
          }
          return colorScheme.surface;
        }),
        checkColor: WidgetStatePropertyAll(colorScheme.onSecondary),
        side: BorderSide(color: colorScheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        surfaceTintColor: colorScheme.surface,
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FixiaRadii.card),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.secondary,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.tertiary,
        contentTextStyle: TextStyle(color: colorScheme.onTertiary),
      ),
      useMaterial3: true,
    );
  }
}
