import 'package:flutter/material.dart';

abstract final class AppColors {
  static const midnightInk = Color(0xFF10152B);
  static const deepCircuit = Color(0xFF1B2340);
  static const sparkYellow = Color(0xFFFFD166);
  static const electricCyan = Color(0xFF4CC9F0);
  static const coralPulse = Color(0xFFFF6B6B);
  static const frost = Color(0xFFF7F8FF);
}

abstract final class AppTheme {
  static ThemeData get dark {
    const display = TextStyle(
      fontFamily: 'sans-serif-condensed',
      fontWeight: FontWeight.w800,
      color: AppColors.frost,
    );
    const body = TextStyle(
      fontFamily: 'sans-serif',
      fontWeight: FontWeight.w500,
      color: AppColors.frost,
    );

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.midnightInk,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.sparkYellow,
        secondary: AppColors.electricCyan,
        surface: AppColors.deepCircuit,
        error: AppColors.coralPulse,
        onPrimary: AppColors.midnightInk,
        onSecondary: AppColors.midnightInk,
        onSurface: AppColors.frost,
        onError: AppColors.midnightInk,
      ),
      textTheme: const TextTheme(
        displayLarge: display,
        displayMedium: display,
        headlineLarge: display,
        headlineMedium: display,
        titleLarge: display,
        bodyLarge: body,
        bodyMedium: body,
        labelLarge: body,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(220, 56),
          textStyle: body.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.electricCyan,
      ),
    );
  }
}
