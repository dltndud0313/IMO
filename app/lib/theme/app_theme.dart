import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_tokens.dart';

/// 앱 테마 (라이트/다크 공통 진입점).
/// Apple Fitness + Freeletics 톤 — 대형 타이포, 소프트 섀도우, 라운드 카드.
class AppTheme {
  // 브랜드 색상 (공통) — 기존 호환 유지
  static const Color primary = Color(0xFF7B96E8);
  static const Color rehab = Color(0xFF5CCDC4);
  static const Color accent = Color(0xFFF5A080);
  static const Color success = Color(0xFF70DEC0);
  static const Color warning = Color(0xFFF5CC70);
  static const Color danger = Color(0xFFF07898);

  // 라이트 서피스
  static const Color bg = Color(0xFFF5F6FA);
  static const Color card = Colors.white;
  static const Color cardElevated = Color(0xFFFBFBFD);
  static const Color textPrimary = Color(0xFF0F1115);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color border = Color(0xFFEAECF0);
  static const Color divider = Color(0xFFF0F1F5);

  // 다크 서피스
  static const Color bgDark = Color(0xFF0B0D10);
  static const Color cardDark = Color(0xFF17191F);
  static const Color cardElevatedDark = Color(0xFF1E2128);
  static const Color textPrimaryDark = Color(0xFFF3F4F6);
  static const Color textSecondaryDark = Color(0xFF9CA3AF);
  static const Color textTertiaryDark = Color(0xFF6B7280);
  static const Color borderDark = Color(0xFF262A33);
  static const Color dividerDark = Color(0xFF1E2128);

  static ThemeData get light {
    final base = ThemeData.light();
    final textTheme = _buildTextTheme(base.textTheme, textPrimary);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: base.colorScheme.copyWith(
        primary: primary,
        secondary: accent,
        surface: card,
        error: danger,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
      ),
      dividerTheme: const DividerThemeData(color: divider, thickness: 1),
      elevatedButtonTheme: _elevatedBtn(),
      outlinedButtonTheme: _outlinedBtn(border, textPrimary),
      textButtonTheme: _textBtn(primary),
      inputDecorationTheme: _inputDecoration(card, border, textSecondary),
      chipTheme: _chipTheme(card, border, textPrimary),
    );
  }

  static ThemeData get dark {
    final base = ThemeData.dark();
    final textTheme = _buildTextTheme(base.textTheme, textPrimaryDark);
    return base.copyWith(
      scaffoldBackgroundColor: bgDark,
      colorScheme: base.colorScheme.copyWith(
        primary: primary,
        secondary: accent,
        surface: cardDark,
        onSurface: textPrimaryDark,
        error: danger,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: bgDark,
        foregroundColor: textPrimaryDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
      ),
      dividerTheme: const DividerThemeData(color: dividerDark, thickness: 1),
      elevatedButtonTheme: _elevatedBtn(),
      outlinedButtonTheme: _outlinedBtn(borderDark, textPrimaryDark),
      textButtonTheme: _textBtn(primary),
      inputDecorationTheme:
          _inputDecoration(cardDark, borderDark, textSecondaryDark),
      chipTheme: _chipTheme(cardDark, borderDark, textPrimaryDark),
      dialogTheme: DialogThemeData(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        ),
      ),
    );
  }

  // ─────────────────────── Helpers ───────────────────────

  static TextTheme _buildTextTheme(TextTheme base, Color color) {
    final t = GoogleFonts.interTextTheme(base).apply(
      bodyColor: color,
      displayColor: color,
    );
    // 대형 숫자/헤드라인 강화 — Apple Fitness 느낌
    return t.copyWith(
      displayLarge: t.displayLarge?.copyWith(
        fontSize: 56,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.5,
        height: 1.0,
      ),
      displayMedium: t.displayMedium?.copyWith(
        fontSize: 44,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
        height: 1.05,
      ),
      displaySmall: t.displaySmall?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      ),
      headlineMedium: t.headlineMedium?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleLarge: t.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: t.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: t.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
      bodyMedium: t.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
      labelLarge: t.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }

  static ElevatedButtonThemeData _elevatedBtn() => ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      );

  static OutlinedButtonThemeData _outlinedBtn(Color borderColor, Color fg) =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: borderColor, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  static TextButtonThemeData _textBtn(Color fg) => TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: fg,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  static InputDecorationTheme _inputDecoration(
    Color fill,
    Color borderColor,
    Color hint,
  ) =>
      InputDecorationTheme(
        filled: true,
        fillColor: fill,
        hintStyle: TextStyle(color: hint, fontSize: 15),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space20,
          vertical: AppTokens.space16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: const BorderSide(color: primary, width: 1.6),
        ),
      );

  static ChipThemeData _chipTheme(Color bg, Color borderColor, Color fg) =>
      ChipThemeData(
        backgroundColor: bg,
        side: BorderSide(color: borderColor),
        labelStyle: TextStyle(
          color: fg,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        ),
      );
}
