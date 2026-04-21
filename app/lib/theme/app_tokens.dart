import 'package:flutter/material.dart';

/// 디자인 토큰 — Apple Fitness + Freeletics 톤
/// 링 기반 프로그레스, 비비드 그라데이션, 대형 타이포, 소프트 섀도우.
class AppTokens {
  AppTokens._();

  // ─────────────────────── Spacing ───────────────────────
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space40 = 40;
  static const double space56 = 56;

  // ─────────────────────── Radius ────────────────────────
  static const double radiusSm = 12;
  static const double radiusMd = 20;
  static const double radiusLg = 28;
  static const double radiusXl = 36;
  static const double radiusPill = 999;

  // ─────────────────────── Shadow ────────────────────────
  static List<BoxShadow> shadowSoft({Color? tint}) => [
        BoxShadow(
          color: (tint ?? Colors.black).withValues(alpha: 0.06),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> shadowMedium({Color? tint}) => [
        BoxShadow(
          color: (tint ?? Colors.black).withValues(alpha: 0.10),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ];

  static List<BoxShadow> shadowGlow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.28),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ];

  // ─────────────────────── Duration ──────────────────────
  static const Duration durFast = Duration(milliseconds: 180);
  static const Duration durMed = Duration(milliseconds: 320);
  static const Duration durSlow = Duration(milliseconds: 560);
}

/// 브랜드 그라데이션 — Apple Fitness의 링 컬러 + Freeletics의 에너지 톤.
class AppGradients {
  AppGradients._();

  /// 주요 CTA / 히어로 (파랑 → 시안)
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7B96E8), Color(0xFF72BFEE)],
  );

  /// 운동 / 액션 (오렌지 → 레드) — Freeletics 에너지
  static const LinearGradient action = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF08060), Color(0xFFF05580)],
  );

  /// 재활 / 회복 (민트 → 그린) — Apple Fitness Move 링 느낌
  static const LinearGradient rehab = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5CCDC4), Color(0xFF70DEC0)],
  );

  /// 성취 / 업적 (퍼플 → 핑크)
  static const LinearGradient achievement = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9B82E8), Color(0xFFD87AB5)],
  );

  /// 다크 히어로 배경
  static const LinearGradient darkHero = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1A1D23), Color(0xFF0F1115)],
  );

  /// Apple Fitness 3-링 컬러 (Move / Exercise / Stand)
  static const Color ringMove = Color(0xFFF07898); // 빨강-핑크 (소프트)
  static const Color ringExercise = Color(0xFF70DEC0); // 민트 (소프트)
  static const Color ringStand = Color(0xFF72BFEE); // 시안 (소프트)
}
