import 'package:flutter/material.dart';

import '../../core/themes/design_tokens.dart';
import '../../core/widgets/imo_card.dart';
import '../model/smartglass_display_models.dart';

class SmartglassFocusCard extends StatelessWidget {
  const SmartglassFocusCard({
    super.key,
    required this.previewLabel,
    required this.phaseSummary,
    required this.phaseLabel,
    required this.poseTitle,
    required this.poseDetail,
    required this.primaryMessage,
    required this.secondaryMessage,
    required this.focusProgress,
    required this.focusProgressLabel,
    required this.reconnectHint,
    required this.tone,
  });

  final String previewLabel;
  final String phaseSummary;
  final String phaseLabel;
  final String poseTitle;
  final String poseDetail;
  final String primaryMessage;
  final String secondaryMessage;
  final double focusProgress;
  final String focusProgressLabel;
  final String reconnectHint;
  final SmartglassDisplayTone tone;

  @override
  Widget build(BuildContext context) {
    final toneColor = smartglassToneColor(
      tone,
      neutral: AppColors.primaryStrong,
      good: AppColors.success,
      warn: AppColors.warning,
      danger: AppColors.error,
    );

    return ImoCard(
      variant: ImoCardVariant.hero,
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: toneColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
                ),
                child: Text(
                  phaseLabel,
                  style: AppTextStyles.caption.copyWith(
                    color: toneColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Preview: $previewLabel',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            phaseSummary,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: focusProgress,
              color: toneColor,
              backgroundColor: AppColors.borderSubtle,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            focusProgressLabel,
            style: AppTextStyles.bodySmall.copyWith(
              color: toneColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            poseTitle,
            style: AppTextStyles.display.copyWith(
              fontSize: 34,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            poseDetail,
            style: AppTextStyles.bodyLg.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            secondaryMessage,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.cardSubtle,
                    borderRadius: BorderRadius.circular(AppSpacing.md),
                  ),
                  child: Text(
                    primaryMessage,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: toneColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSpacing.md),
                    border: Border.all(
                      color: toneColor.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '중간 연결 복구',
                        style: AppTextStyles.caption.copyWith(
                          color: toneColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(reconnectHint, style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
