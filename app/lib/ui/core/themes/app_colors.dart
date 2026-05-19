import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFFF7FCFF);
  static const backgroundSoftGreen = Color(0xFFF7FFF5);

  static const card = Color(0xFFFFFFFF);
  static const cardSubtle = Color(0xFFF3F6F8);
  static const border = Color(0xFFE5EDF3);
  static const divider = Color(0xFFE9EEF3);

  static const primary = Color(0xFF5BBEFF);
  static const primaryStrong = Color(0xFF2398E8);
  static const secondary = Color(0xFF9BE56D);

  static const textPrimary = Color(0xFF1F2937);
  static const textSecondary = Color(0xFF6B7280);
  static const textTertiary = Color(0xFF9CA3AF);

  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const disabledBg = Color(0xFFE5E7EB);
  static const disabledText = Color(0xFF9CA3AF);

  static const heatmapBg = Color(0xFF0F172A);
  static const heatmapInactive = Color(0xFF334155);
  static const heatmapLow = primary;
  static const heatmapNormal = secondary;
  static const heatmapHigh = warning;
  static const heatmapDanger = error;

  // Temporary compatibility aliases for existing foundation code.
  static const surface = card;
  static const accent = secondary;
  static const danger = error;
  static const textMuted = textTertiary;
}
