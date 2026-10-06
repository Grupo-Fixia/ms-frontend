import 'package:flutter/material.dart';

/// Colores oficiales del Brand Board Fixia v1.0 (GC-182).
abstract final class FixiaColors {
  /// Texto, fondos oscuros y wordmark.
  static const primary = Color(0xFF01255D);

  /// Acciones, enlaces e iconografía activa.
  static const secondary = Color(0xFF006DFD);

  /// Solo confirmación, éxito y el checkmark de marca.
  static const accent = Color(0xFF00B79E);

  /// Superficie secundaria y tarjetas destacadas.
  static const supportBackground = Color(0xFFDCEBFF);

  static const textPrimary = Color(0xFF0B1220);
  static const textSecondary = Color(0xFF5B6B7C);
  static const neutralBackground = Color(0xFFF4F7FB);
  static const white = Color(0xFFFFFFFF);
  static const error = Color(0xFFB3261E);
}

abstract final class FixiaRadii {
  static const input = 12.0;
  static const card = 20.0;
}

/// Decoración de las tarjetas de contenido.
///
/// No se usa `ThemeData.cardTheme` porque su tipo cambió entre Flutter 3.22
/// (`CardTheme`, versión del Dockerfile) y 3.27+ (`CardThemeData`): ningún
/// valor compila en ambas. Una `BoxDecoration` funciona igual en todas.
abstract final class FixiaDecorations {
  static final card = BoxDecoration(
    color: FixiaColors.white,
    borderRadius: BorderRadius.circular(FixiaRadii.card),
    border: Border.all(color: const Color(0xFFE3EAF4)),
  );
}

/// Tema de la app según el Brand Board v1.0: tipografía Inter y la jerarquía
/// H1 800 32/40, H2 700 24/32, cuerpo 400 16/24, botón 600 15/20,
/// caption 500 13/18.
abstract final class FixiaTheme {
  static const fontFamily = 'Inter';

  static ThemeData get light {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: FixiaColors.primary,
      onPrimary: FixiaColors.white,
      primaryContainer: FixiaColors.supportBackground,
      onPrimaryContainer: FixiaColors.primary,
      secondary: FixiaColors.secondary,
      onSecondary: FixiaColors.white,
      tertiary: FixiaColors.accent,
      onTertiary: FixiaColors.white,
      error: FixiaColors.error,
      onError: FixiaColors.white,
      surface: FixiaColors.white,
      onSurface: FixiaColors.textPrimary,
      onSurfaceVariant: FixiaColors.textSecondary,
      outline: FixiaColors.textSecondary,
      outlineVariant: FixiaColors.supportBackground,
    );

    const textTheme = TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        height: 40 / 32,
        fontWeight: FontWeight.w800,
        color: FixiaColors.primary,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        height: 32 / 24,
        fontWeight: FontWeight.w700,
        color: FixiaColors.primary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w400,
        color: FixiaColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        height: 22 / 15,
        fontWeight: FontWeight.w400,
        color: FixiaColors.textPrimary,
      ),
      labelLarge: TextStyle(
        fontSize: 15,
        height: 20 / 15,
        fontWeight: FontWeight.w600,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        height: 18 / 13,
        fontWeight: FontWeight.w500,
        color: FixiaColors.textSecondary,
      ),
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(FixiaRadii.input),
      borderSide: const BorderSide(color: Color(0xFFC9D6E8)),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: FixiaColors.neutralBackground,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FixiaColors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide:
              const BorderSide(color: FixiaColors.secondary, width: 1.5),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: FixiaColors.error),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: FixiaColors.error, width: 1.5),
        ),
        labelStyle: const TextStyle(color: FixiaColors.textSecondary),
        floatingLabelStyle: const TextStyle(color: FixiaColors.secondary),
        helperStyle: const TextStyle(color: FixiaColors.textSecondary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: FixiaColors.secondary,
          foregroundColor: FixiaColors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FixiaRadii.input),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: FixiaColors.secondary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: FixiaColors.primary,
        contentTextStyle: TextStyle(color: FixiaColors.white),
      ),
    );
  }
}
