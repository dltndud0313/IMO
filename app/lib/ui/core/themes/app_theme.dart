import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

ThemeData buildCoreAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      error: AppColors.error,
      surface: AppColors.card,
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    textTheme: base.textTheme.copyWith(
      displaySmall: AppTextStyles.display,
      titleLarge: AppTextStyles.title,
      titleMedium: AppTextStyles.sectionTitle,
      bodyMedium: AppTextStyles.body,
      bodySmall: AppTextStyles.bodySmall,
      labelLarge: AppTextStyles.button,
      labelMedium: AppTextStyles.label,
      labelSmall: AppTextStyles.caption,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      titleTextStyle: AppTextStyles.sectionTitle,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: AppSpacing.borderWidth,
      space: AppSpacing.borderWidth,
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: const BorderSide(
          color: AppColors.border,
          width: AppSpacing.borderWidth,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      labelStyle: AppTextStyles.bodySmall,
      hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        borderSide: const BorderSide(
          color: AppColors.border,
          width: AppSpacing.borderWidth,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        borderSide: const BorderSide(
          color: AppColors.primaryStrong,
          width: AppSpacing.borderWidth,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        borderSide: const BorderSide(
          color: AppColors.disabledBg,
          width: AppSpacing.borderWidth,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, AppSpacing.buttonHeight),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.card,
        disabledBackgroundColor: AppColors.disabledBg,
        disabledForegroundColor: AppColors.disabledText,
        textStyle: AppTextStyles.button,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.card,
      indicatorColor: AppColors.backgroundSoftGreen,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppTextStyles.caption.copyWith(color: AppColors.primaryStrong)
            : AppTextStyles.caption,
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.primaryStrong
              : AppColors.textTertiary,
        ),
      ),
    ),
  );
}

ThemeData buildCoreDarkAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      brightness: Brightness.dark,
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      error: AppColors.error,
      surface: const Color(0xFF1E293B),
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: const Color(0xFF0F172A),
    textTheme: base.textTheme.copyWith(
      displaySmall: AppTextStyles.display.copyWith(color: Colors.white),
      titleLarge: AppTextStyles.title.copyWith(color: Colors.white),
      titleMedium: AppTextStyles.sectionTitle.copyWith(color: Colors.white),
      bodyMedium: AppTextStyles.body.copyWith(color: const Color(0xFFE5E7EB)),
      bodySmall: AppTextStyles.bodySmall.copyWith(color: const Color(0xFFCBD5E1)),
      labelLarge: AppTextStyles.button,
      labelMedium: AppTextStyles.label.copyWith(color: Colors.white),
      labelSmall: AppTextStyles.caption.copyWith(color: const Color(0xFFCBD5E1)),
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: Color(0xFF0F172A),
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF334155),
      thickness: AppSpacing.borderWidth,
      space: AppSpacing.borderWidth,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF1E293B),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: const BorderSide(
          color: Color(0xFF334155),
          width: AppSpacing.borderWidth,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1E293B),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      labelStyle: AppTextStyles.bodySmall.copyWith(color: const Color(0xFFCBD5E1)),
      hintStyle: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF94A3B8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        borderSide: const BorderSide(
          color: Color(0xFF334155),
          width: AppSpacing.borderWidth,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        borderSide: const BorderSide(
          color: AppColors.primary,
          width: AppSpacing.borderWidth,
        ),
      ),
    ),
  );
}
