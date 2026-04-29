import 'package:flutter/material.dart';

import '../themes/design_tokens.dart';

enum ImoButtonVariant { primary, secondary, outline, ghost, danger }

enum ImoButtonSize { sm, md, lg }

class ImoButton extends StatelessWidget {
  const ImoButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isExpanded,
    this.variant = ImoButtonVariant.primary,
    this.size = ImoButtonSize.lg,
    this.loading = false,
    this.leftIcon,
    this.rightIcon,
    this.fullWidth,
    this.disabled = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool? isExpanded;
  final ImoButtonVariant variant;
  final ImoButtonSize size;
  final bool loading;
  final Widget? leftIcon;
  final Widget? rightIcon;
  final bool? fullWidth;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final isDisabled = disabled || loading || onPressed == null;
    final colors = _resolveColors();
    final height = _resolveHeight();
    final radius = _resolveRadius();
    final effectiveLeftIcon =
        leftIcon ?? (icon == null ? null : Icon(icon, size: 18));

    final child = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(colors.foreground),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (effectiveLeftIcon != null) ...[
                IconTheme(
                  data: IconThemeData(color: colors.foreground, size: 18),
                  child: effectiveLeftIcon,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.button.copyWith(
                    color: colors.foreground,
                  ),
                ),
              ),
              if (rightIcon != null) ...[
                const SizedBox(width: AppSpacing.xs),
                IconTheme(
                  data: IconThemeData(color: colors.foreground, size: 18),
                  child: rightIcon!,
                ),
              ],
            ],
          );

    final button = Material(
      color: colors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: colors.border == null
            ? BorderSide.none
            : BorderSide(color: colors.border!),
      ),
      child: InkWell(
        onTap: isDisabled ? null : onPressed,
        borderRadius: BorderRadius.circular(radius),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: isDisabled ? 0.5 : 1,
          child: Container(
            height: height,
            padding: _resolvePadding(),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );

    final shouldExpand = fullWidth ?? isExpanded ?? true;
    if (shouldExpand) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }

  double _resolveHeight() {
    switch (size) {
      case ImoButtonSize.sm:
        return AppSpacing.buttonHeightSm;
      case ImoButtonSize.md:
        return AppSpacing.buttonHeightMd;
      case ImoButtonSize.lg:
        return AppSpacing.buttonHeight;
    }
  }

  double _resolveRadius() {
    switch (size) {
      case ImoButtonSize.sm:
        return AppSpacing.sm;
      case ImoButtonSize.md:
        return AppSpacing.buttonRadius;
      case ImoButtonSize.lg:
        return AppSpacing.buttonRadius;
    }
  }

  EdgeInsets _resolvePadding() {
    switch (size) {
      case ImoButtonSize.sm:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.sm);
      case ImoButtonSize.md:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.md);
      case ImoButtonSize.lg:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.lg);
    }
  }

  _ButtonColors _resolveColors() {
    switch (variant) {
      case ImoButtonVariant.primary:
        return const _ButtonColors(
          background: AppColors.primary,
          foreground: AppColors.card,
        );
      case ImoButtonVariant.secondary:
        return const _ButtonColors(
          background: AppColors.secondary,
          foreground: AppColors.textPrimary,
        );
      case ImoButtonVariant.outline:
        return const _ButtonColors(
          background: Colors.transparent,
          foreground: AppColors.textPrimary,
          border: AppColors.border,
        );
      case ImoButtonVariant.ghost:
        return const _ButtonColors(
          background: Colors.transparent,
          foreground: AppColors.textPrimary,
        );
      case ImoButtonVariant.danger:
        return const _ButtonColors(
          background: AppColors.error,
          foreground: AppColors.card,
        );
    }
  }
}

class _ButtonColors {
  const _ButtonColors({
    required this.background,
    required this.foreground,
    this.border,
  });

  final Color background;
  final Color foreground;
  final Color? border;
}
