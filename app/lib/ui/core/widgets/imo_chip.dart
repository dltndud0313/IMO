import 'package:flutter/material.dart';

import '../themes/design_tokens.dart';

enum ImoChipVariant { defaultChip, selected, outline, success, warning, error }

class ImoChip extends StatelessWidget {
  const ImoChip({
    super.key,
    required this.label,
    this.selected = false,
    this.disabled = false,
    this.variant = ImoChipVariant.defaultChip,
    this.icon,
    this.onTap,
  });

  final String label;
  final bool selected;
  final bool disabled;
  final ImoChipVariant variant;
  final Widget? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = _resolvePalette(selected ? ImoChipVariant.selected : variant);
    final chip = Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        border: palette.border == null
            ? null
            : Border.all(color: palette.border!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            IconTheme(
              data: IconThemeData(color: palette.foreground, size: 14),
              child: icon!,
            ),
            const SizedBox(width: AppSpacing.xxs),
          ],
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: palette.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    final disabledChip = Opacity(opacity: disabled ? 0.5 : 1, child: chip);
    if (onTap == null || disabled) {
      return disabledChip;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        child: disabledChip,
      ),
    );
  }

  _ChipPalette _resolvePalette(ImoChipVariant variant) {
    switch (variant) {
      case ImoChipVariant.defaultChip:
        return const _ChipPalette(
          background: AppColors.cardSubtle,
          foreground: AppColors.textSecondary,
        );
      case ImoChipVariant.selected:
        return _ChipPalette(
          background: AppColors.primary.withValues(alpha: 0.14),
          foreground: AppColors.primaryStrong,
        );
      case ImoChipVariant.outline:
        return const _ChipPalette(
          background: Colors.transparent,
          foreground: AppColors.textSecondary,
          border: AppColors.border,
        );
      case ImoChipVariant.success:
        return _ChipPalette(
          background: AppColors.success.withValues(alpha: 0.14),
          foreground: const Color(0xFF15803D),
        );
      case ImoChipVariant.warning:
        return _ChipPalette(
          background: AppColors.warning.withValues(alpha: 0.16),
          foreground: const Color(0xFFB97509),
        );
      case ImoChipVariant.error:
        return _ChipPalette(
          background: AppColors.error.withValues(alpha: 0.14),
          foreground: const Color(0xFFB91C1C),
        );
    }
  }
}

class _ChipPalette {
  const _ChipPalette({
    required this.background,
    required this.foreground,
    this.border,
  });

  final Color background;
  final Color foreground;
  final Color? border;
}
