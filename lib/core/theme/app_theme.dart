import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppFonts {
  static const mobile = 'PlusJakartaSans';
  static const web = 'Inter';
}

abstract final class AppText {
  // Pas de fontFamily : elle vient du thème (Plus Jakarta Sans mobile, Inter dans WebShell).
  static const _base = TextStyle(
    color: AppColors.ink,
    height: 1.3,
    letterSpacing: -0.1,
  );

  static final display = _base.copyWith(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    height: 1.12,
    letterSpacing: -0.6,
  );
  static final h1 = _base.copyWith(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    height: 1.15,
    letterSpacing: -0.5,
  );
  static final h2 = _base.copyWith(fontSize: 20, fontWeight: FontWeight.w700);
  static final h3 = _base.copyWith(fontSize: 17, fontWeight: FontWeight.w700);
  static final body = _base.copyWith(fontSize: 14, fontWeight: FontWeight.w500);
  static final bodyStrong = _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );
  static final secondary = _base.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );
  static final small = _base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );
  static final label = _base.copyWith(fontSize: 13, fontWeight: FontWeight.w700);
  static final button = _base.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
  static final amount = _base.copyWith(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
  );

  /// Variante Inter pour les tableaux de bord web.
  static TextStyle web(TextStyle s) => s.copyWith(fontFamily: AppFonts.web);
}

abstract final class AppTheme {
  static ThemeData light({bool web = false}) {
    final family = web ? AppFonts.web : AppFonts.mobile;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      primary: AppColors.ink,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      error: AppColors.error,
      surface: AppColors.card,
      onSurface: AppColors.ink,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: family,
      scaffoldBackgroundColor: AppColors.bgTop,
      splashFactory: InkSparkle.splashFactory,
      textTheme: const TextTheme().apply(
        fontFamily: family,
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      dividerColor: AppColors.cardBorder,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: AppText.secondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusField),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusField),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusField),
          borderSide: const BorderSide(color: AppColors.ink, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusField),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusField),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
    );
  }
}
