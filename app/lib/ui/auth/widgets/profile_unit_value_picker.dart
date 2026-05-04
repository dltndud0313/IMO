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
    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        side: const BorderSide(color: AppColors.border, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        child: SizedBox(
          height: 72,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: AppTextStyles.title),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  unit,
                  style: AppTextStyles.bodyLg.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
