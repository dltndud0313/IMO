import 'package:flutter/material.dart';

import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';

class HistoryDetailScreen extends StatelessWidget {
  const HistoryDetailScreen({super.key, this.sessionId = 'sess_20260429_001'});

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '2026-4-29',
      subtitle: '하루 운동 분석',
      showBackButton: true,
      scrollable: true,
      body: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DayHeroCard(),
          SizedBox(height: AppSpacing.md),
          _ActivationCard(),
          SizedBox(height: AppSpacing.md),
          _BalanceCard(),
          SizedBox(height: AppSpacing.md),
          _FatigueCard(),
          SizedBox(height: AppSpacing.lg),
          Text('운동별 기록', style: AppTextStyles.sectionTitle),
          SizedBox(height: AppSpacing.sm),
          _WorkoutRecordCard(),
        ],
      ),
    );
  }
}

class _DayHeroCard extends StatelessWidget {
  const _DayHeroCard();

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      paddingSize: ImoCardPadding.lg,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, Color(0xFF6FA9E8)],
          ),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '하루 요약',
                style: AppTextStyles.sectionTitle.copyWith(
                  color: AppColors.card,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: const [
                  Expanded(
                    child: _HeroMetric(label: '운동', value: '1', unit: '개'),
                  ),
                  Expanded(
                    child: _HeroMetric(label: '총 반복', value: '30', unit: '회'),
                  ),
                  Expanded(
                    child: _HeroMetric(label: '시간', value: '1', unit: '분'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(color: Color(0x55FFFFFF)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '3세트  ·  1분',
                style: AppTextStyles.bodyLg.copyWith(color: AppColors.card),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.body.copyWith(color: AppColors.card)),
        const SizedBox(height: AppSpacing.xs),
        Text.rich(
          TextSpan(
            text: value,
            children: [TextSpan(text: unit, style: AppTextStyles.body)],
          ),
          style: AppTextStyles.metric.copyWith(color: AppColors.card),
        ),
      ],
    );
  }
}

class _ActivationCard extends StatelessWidget {
  const _ActivationCard();

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('근육 활성도', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.md),
          const _ActivationRow(
            label: '대흉근',
            value: 82,
            level: '높음',
            color: AppColors.heatmapHigh,
          ),
          const _ActivationRow(
            label: '삼두근',
            value: 68,
            level: '보통',
            color: AppColors.heatmapNormal,
          ),
          const _ActivationRow(
            label: '전면 삼각근',
            value: 54,
            level: '보통',
            color: AppColors.heatmapNormal,
          ),
          const _ActivationRow(
            label: '승모근',
            value: 28,
            level: '낮음',
            color: AppColors.heatmapLow,
          ),
        ],
      ),
    );
  }
}

class _ActivationRow extends StatelessWidget {
  const _ActivationRow({
    required this.label,
    required this.value,
    required this.level,
    required this.color,
  });

  final String label;
  final int value;
  final String level;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        children: [
          Row(
            children: [
              Text(label, style: AppTextStyles.label),
              const Spacer(),
              Text('$value% · $level', style: AppTextStyles.body),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 8,
              backgroundColor: AppColors.cardSubtle,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard();

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('좌우 밸런스', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.md),
          const _BalanceMiniRow(label: '가슴', left: 78, right: 82),
          const _BalanceMiniRow(label: '삼두근', left: 71, right: 74),
          const _BalanceMiniRow(label: '어깨', left: 65, right: 72),
        ],
      ),
    );
  }
}

class _BalanceMiniRow extends StatelessWidget {
  const _BalanceMiniRow({
    required this.label,
    required this.left,
    required this.right,
  });

  final String label;
  final int left;
  final int right;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: AppTextStyles.label),
              const Spacer(),
              Text('좌 $left% · 우 $right%', style: AppTextStyles.body),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 26,
                  color: AppColors.primary.withValues(alpha: 0.72),
                ),
              ),
              Container(width: 4, height: 26, color: AppColors.card),
              Expanded(
                child: Container(
                  height: 26,
                  color: AppColors.secondary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FatigueCard extends StatelessWidget {
  const _FatigueCard();

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      variant: ImoCardVariant.outlined,
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('자세·피로', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.md),
          const _InfoLine(label: '보상동작', value: '3회'),
          const _InfoLine(label: '피로 시작 시점', value: '3세트 7회차'),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Text(label, style: AppTextStyles.body),
          const Spacer(),
          Text(value, style: AppTextStyles.label),
        ],
      ),
    );
  }
}

class _WorkoutRecordCard extends StatelessWidget {
  const _WorkoutRecordCard();

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      paddingSize: ImoCardPadding.lg,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.cardSubtle,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              color: AppColors.primaryStrong,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('푸시업', style: AppTextStyles.sectionTitle),
                const SizedBox(height: AppSpacing.xxs),
                Text('3세트 · 30회 · 1분', style: AppTextStyles.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
