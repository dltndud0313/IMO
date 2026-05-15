import 'package:flutter/material.dart';

import '../../core/themes/design_tokens.dart';

class ProfileUnitValuePicker extends StatelessWidget {
  const ProfileUnitValuePicker({
    super.key,
    required this.value,
    required this.unit,
    required this.onTap,
  });

  final String value;
  final String unit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unitLabel = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        unit,
        style: AppTextStyles.bodyLg.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 숫자를 정확히 가운데 두기 위한 좌측 균형용(투명) 단위.
            Opacity(opacity: 0, child: unitLabel),
            const SizedBox(width: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.only(bottom: 4),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.textSecondary,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                value,
                style: AppTextStyles.display.copyWith(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            unitLabel,
          ],
        ),
      ),
    );
  }
}
