import 'package:flutter/material.dart';

import '../../core/themes/design_tokens.dart';

class GenderSelector extends StatelessWidget {
  const GenderSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final String? selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final gender in const ['남성', '여성', '기타']) ...[
          _GenderChoiceButton(
            label: gender,
            selected: selected == gender,
            onTap: () => onChanged(gender),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _GenderChoiceButton extends StatelessWidget {
  const _GenderChoiceButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.12)
          : AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        child: SizedBox(
          height: 58,
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.bodyLg.copyWith(
                color: selected
                    ? AppColors.primaryStrong
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
