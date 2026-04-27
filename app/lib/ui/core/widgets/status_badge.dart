import 'package:flutter/material.dart';

import '../themes/design_tokens.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.color = AppColors.primary,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
