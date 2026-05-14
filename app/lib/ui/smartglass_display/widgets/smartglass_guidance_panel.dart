import 'package:flutter/material.dart';

import '../../core/themes/design_tokens.dart';
import '../../core/widgets/imo_card.dart';
import '../model/smartglass_display_models.dart';

class SmartglassGuidancePanel extends StatelessWidget {
  const SmartglassGuidancePanel({
    super.key,
    required this.state,
  });

  final SmartglassDisplayState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ImoCard(
          paddingSize: ImoCardPadding.md,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('상태 요약', style: AppTextStyles.sectionTitle),
              const SizedBox(height: AppSpacing.sm),
              ...state.statusHighlights.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Icon(
                          Icons.flash_on_rounded,
                          size: 14,
                          color: AppColors.primaryStrong,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(item, style: AppTextStyles.body),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ImoCard(
          paddingSize: ImoCardPadding.md,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('코칭 큐', style: AppTextStyles.sectionTitle),
              const SizedBox(height: AppSpacing.sm),
              ...state.coachCues.map(
                (cue) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _CueTile(cue: cue),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ImoCard(
          paddingSize: ImoCardPadding.md,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('표시 원칙', style: AppTextStyles.sectionTitle),
              const SizedBox(height: AppSpacing.sm),
              Text(state.readinessLabel, style: AppTextStyles.bodyLg),
              const SizedBox(height: AppSpacing.xs),
              Text(state.readinessDetail, style: AppTextStyles.body),
            ],
          ),
        ),
      ],
    );
  }
}

class _CueTile extends StatelessWidget {
  const _CueTile({required this.cue});

  final SmartglassCoachCue cue;

  @override
  Widget build(BuildContext context) {
    final toneColor = smartglassToneColor(
      cue.tone,
      neutral: AppColors.primaryStrong,
      good: AppColors.success,
      warn: AppColors.warning,
      danger: AppColors.error,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: toneColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: toneColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cue.label,
            style: AppTextStyles.body.copyWith(
              color: toneColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(cue.detail, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}
