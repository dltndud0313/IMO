import 'package:flutter/material.dart';

import '../themes/design_tokens.dart';
import 'imo_button.dart';

class ImoConfirmDialog extends StatelessWidget {
  const ImoConfirmDialog({
    super.key,
    required this.message,
    required this.onConfirm,
    this.title,
    this.confirmLabel = '확인',
    this.cancelLabel = '취소',
    this.danger = false,
    this.pillButtons = false,
  });

  final String? title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool danger;
  final bool pillButtons;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Text(
                title!,
                textAlign: TextAlign.center,
                style: AppTextStyles.sectionTitle,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyLg.copyWith(height: 1.5),
            ),
            const SizedBox(height: AppSpacing.lg),
            pillButtons ? _buildPillButtons(context) : _buildStandardButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStandardButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ImoButton(
            label: confirmLabel,
            variant: danger
                ? ImoButtonVariant.danger
                : ImoButtonVariant.primary,
            onPressed: onConfirm,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: ImoButton(
            label: cancelLabel,
            variant: ImoButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }

  Widget _buildPillButtons(BuildContext context) {
    final confirmColor = danger ? AppColors.error : AppColors.primary;
    return Row(
      children: [
        Expanded(
          child: _PillDialogButton(
            label: confirmLabel,
            background: confirmColor,
            foreground: AppColors.card,
            onPressed: onConfirm,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _PillDialogButton(
            label: cancelLabel,
            background: AppColors.disabledBg,
            foreground: AppColors.textPrimary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}

class _PillDialogButton extends StatelessWidget {
  const _PillDialogButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(AppSpacing.pillRadius);
    return Material(
      color: background,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      child: InkWell(
        onTap: onPressed,
        borderRadius: borderRadius,
        child: SizedBox(
          height: AppSpacing.buttonHeightMd,
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.button.copyWith(color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}
