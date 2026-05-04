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
  });

  final String? title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool danger;
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
            Row(
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
            ),
          ],
        ),
      ),
    );
  }
}
