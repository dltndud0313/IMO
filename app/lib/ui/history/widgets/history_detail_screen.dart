import 'package:flutter/material.dart';

import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';

class HistoryDetailScreen extends StatelessWidget {
  const HistoryDetailScreen({
    super.key,
    this.sessionId = 'sess_20260427_001',
  });

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '기록 상세',
      subtitle: sessionId,
      showBackButton: true,
      scrollable: true,
      body: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailHeroCard(),
          SizedBox(height: AppSpacing.sectionGap),
          _DetailMetricGrid(),
          SizedBox(height: AppSpacing.md),
          _DetailSetCard(),
          SizedBox(height: AppSpacing.md),
          _DetailInsightCard(),
        ],
      ),
    );
  }
}

class _DetailHeroCard extends StatelessWidget {
  const _DetailHeroCard();

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      variant: ImoCardVariant.hero,
      paddingSize: ImoCardPadding.lg,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryStrong],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              color: AppColors.card,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('푸시업', style: AppTextStyles.sectionTitle),
                const SizedBox(height: AppSpacing.xxs),
                Text('2026년 4월 27일 09:28', style: AppTextStyles.caption),
              ],
            ),
          ),
          const StatusBadge(label: '정상 완료', variant: StatusVariant.success),
        ],
      ),
    );
  }
}

class _DetailMetricGrid extends StatelessWidget {
  const _DetailMetricGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.45,
      children: const [
        _DetailMetric(label: '총 횟수', value: '33'),
        _DetailMetric(label: '유효 횟수', value: '31'),
        _DetailMetric(label: '운동 시간', value: '7분 12초'),
        _DetailMetric(label: '보상동작', value: '4'),
      ],
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      paddingSize: ImoCardPadding.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(value, style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.xxs),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _DetailSetCard extends StatelessWidget {
  const _DetailSetCard();

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('세트 로그', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.md),
          const _SetLogLine(index: 1, reps: '12 / 12', speed: '보통'),
          const SizedBox(height: AppSpacing.sm),
          const _SetLogLine(index: 2, reps: '12 / 12', speed: '보통'),
          const SizedBox(height: AppSpacing.sm),
          const _SetLogLine(index: 3, reps: '9 / 10', speed: '느림'),
        ],
      ),
    );
  }
}

class _SetLogLine extends StatelessWidget {
  const _SetLogLine({
    required this.index,
    required this.reps,
    required this.speed,
  });

  final int index;
  final String reps;
  final String speed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$index세트', style: AppTextStyles.label),
        const Spacer(),
        Text('$reps회 · $speed', style: AppTextStyles.bodySmall),
      ],
    );
  }
}

class _DetailInsightCard extends StatelessWidget {
  const _DetailInsightCard();

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      variant: ImoCardVariant.subtle,
      paddingSize: ImoCardPadding.lg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.insights_rounded,
            color: AppColors.primaryStrong,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '추후 session_id 기준으로 상세 데이터를 불러오고, 반복 로그는 session_id + rep_number 인덱스 순서로 조회합니다.',
              style: AppTextStyles.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
