import 'package:flutter/material.dart';

import '../themes/design_tokens.dart';

enum StatusVariant { success, warning, error, info, neutral }

enum StatusBadgeSize { sm, md }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.color = AppColors.primary,
    this.variant,
    this.size = StatusBadgeSize.sm,
    this.showDot = true,
  });

  final String label;
  final Color color;
  final StatusVariant? variant;
  final StatusBadgeSize size;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final palette = variant == null
        ? _BadgePalette(
            background: color.withValues(alpha: 0.12),
            foreground: color,
            dot: color,
          )
        : _resolvePalette(variant!);
    final isSmall = size == StatusBadgeSize.sm;

    return Container(
      height: isSmall ? 22 : 26,
      padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 10),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: palette.dot,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.xxs),
          ],
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: palette.foreground,
              fontSize: isSmall ? 10 : 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  _BadgePalette _resolvePalette(StatusVariant variant) {
    switch (variant) {
      case StatusVariant.success:
        return _BadgePalette(
          background: AppColors.success.withValues(alpha: 0.14),
          foreground: const Color(0xFF15803D),
          dot: AppColors.success,
        );
      case StatusVariant.warning:
        return _BadgePalette(
          background: AppColors.warning.withValues(alpha: 0.16),
          foreground: const Color(0xFFB97509),
          dot: AppColors.warning,
        );
      case StatusVariant.error:
        return _BadgePalette(
          background: AppColors.error.withValues(alpha: 0.14),
          foreground: const Color(0xFFB91C1C),
          dot: AppColors.error,
        );
      case StatusVariant.info:
        return _BadgePalette(
          background: AppColors.primary.withValues(alpha: 0.14),
          foreground: AppColors.primaryStrong,
          dot: AppColors.primary,
        );
      case StatusVariant.neutral:
        return const _BadgePalette(
          background: AppColors.cardSubtle,
          foreground: AppColors.textSecondary,
          dot: AppColors.textTertiary,
        );
    }
  }
}

class _BadgePalette {
  const _BadgePalette({
    required this.background,
    required this.foreground,
    required this.dot,
  });

  final Color background;
  final Color foreground;
  final Color dot;
}
