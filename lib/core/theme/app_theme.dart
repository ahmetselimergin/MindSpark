import 'package:flutter/material.dart';

abstract final class AppColors {
  static const voidNavy = Color(0xFF080D1C);
  static const panelNavy = Color(0xFF111A2E);
  static const gridBlue = Color(0xFF263653);
  static const sparkCyan = Color(0xFF62E6FF);
  static const pulseYellow = Color(0xFFFFD76A);
  static const signalCoral = Color(0xFFFF6B81);
  static const mint = Color(0xFF6EE7A8);
  static const cloud = Color(0xFFF4F7FF);

  // Compatibility names retained for the existing Home and Result artwork.
  static const midnightInk = voidNavy;
  static const deepCircuit = panelNavy;
  static const sparkYellow = pulseYellow;
  static const electricCyan = sparkCyan;
  static const coralPulse = signalCoral;
  static const frost = cloud;
}

abstract final class AppTheme {
  static ThemeData get dark {
    const display = TextStyle(
      fontFamily: 'sans-serif',
      fontWeight: FontWeight.w800,
      color: AppColors.cloud,
    );
    const body = TextStyle(
      fontFamily: 'sans-serif',
      fontWeight: FontWeight.w500,
      color: AppColors.cloud,
    );

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.voidNavy,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.pulseYellow,
        secondary: AppColors.sparkCyan,
        surface: AppColors.panelNavy,
        error: AppColors.signalCoral,
        onPrimary: AppColors.voidNavy,
        onSecondary: AppColors.voidNavy,
        onSurface: AppColors.cloud,
        onError: AppColors.voidNavy,
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
        color: AppColors.sparkCyan,
      ),
      iconTheme: const IconThemeData(color: AppColors.cloud),
    );
  }
}
