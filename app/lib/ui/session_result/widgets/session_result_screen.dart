import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';

class SessionResultScreen extends StatelessWidget {
  const SessionResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '운동 결과',
      subtitle: '푸시업 완료',
      scrollable: true,
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ImoButton(
            label: '홈으로 돌아가기',
            onPressed: () => context.go('/home'),
          ),
          const SizedBox(height: AppSpacing.xs),
          ImoButton(
            label: '기록 보기',
            variant: ImoButtonVariant.outline,
            onPressed: () => context.go('/history'),
          ),
        ],
      ),
      body: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ResultHeroCard(),
          SizedBox(height: AppSpacing.sectionGap),
          _ResultMetricGrid(),
          SizedBox(height: AppSpacing.md),
          _SetResultsCard(),
          SizedBox(height: AppSpacing.md),
          _MuscleMapCard(),
          SizedBox(height: AppSpacing.md),
          _SessionCommentCard(),
        ],
      ),
    );
  }
}

class _ResultHeroCard extends StatelessWidget {
  const _ResultHeroCard();

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      variant: ImoCardVariant.hero,
      paddingSize: ImoCardPadding.lg,
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.secondary],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.24),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: AppColors.card,
              size: 42,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('운동 완료', style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '운동 결과가 저장되었어요. 기록에서 다시 확인할 수 있습니다.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body,
          ),
          const SizedBox(height: AppSpacing.md),
          const Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.center,
            children: [
              StatusBadge(
                label: '정상 완료',
                variant: StatusVariant.success,
                size: StatusBadgeSize.md,
              ),
              StatusBadge(
                label: '자동 종료',
                variant: StatusVariant.info,
                size: StatusBadgeSize.md,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultMetricGrid extends StatelessWidget {
  const _ResultMetricGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.42,
      children: const [
        _MetricTile(
          icon: Icons.fitness_center_rounded,
          label: '총 횟수',
          value: '33',
          tint: AppColors.primary,
        ),
        _MetricTile(
          icon: Icons.check_circle_rounded,
          label: '유효 횟수',
          value: '31',
          tint: AppColors.success,
        ),
        _MetricTile(
          icon: Icons.timer_rounded,
          label: '운동 시간',
          value: '7분 12초',
          tint: AppColors.warning,
        ),
        _MetricTile(
          icon: Icons.warning_amber_rounded,
          label: '보상동작',
          value: '4',
          tint: AppColors.error,
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      paddingSize: ImoCardPadding.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppSpacing.sm),
            ),
            child: Icon(icon, color: tint, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: AppTextStyles.sectionTitle),
              const SizedBox(height: AppSpacing.xxs),
              Text(label, style: AppTextStyles.caption),
            ],
          ),
        ],
      ),
    );
  }
}

class _SetResultsCard extends StatelessWidget {
  const _SetResultsCard();

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('세트별 결과', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.md),
          for (final result in _setResults) ...[
            _SetResultRow(result: result),
            if (result != _setResults.last) const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _SetResultRow extends StatelessWidget {
  const _SetResultRow({required this.result});

  final _SetResult result;

  @override
  Widget build(BuildContext context) {
    final completed = result.actualReps >= result.targetReps;

    return ImoCard(
      variant: completed ? ImoCardVariant.subtle : ImoCardVariant.outlined,
      paddingSize: ImoCardPadding.sm,
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: completed ? AppColors.success : AppColors.warning,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${result.index}',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.card,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${result.index}세트', style: AppTextStyles.label),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${result.actualReps}/${result.targetReps}회 · ${result.speed}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          StatusBadge(
            label: completed ? '완료' : '미달',
            variant: completed ? StatusVariant.success : StatusVariant.warning,
          ),
        ],
      ),
    );
  }
}

class _MuscleMapCard extends StatelessWidget {
  const _MuscleMapCard();

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.track_changes_rounded,
                color: AppColors.primaryStrong,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text('근육 활성 지도', style: AppTextStyles.label),
              const Spacer(),
              const StatusBadge(label: '예시', variant: StatusVariant.neutral),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            height: 188,
            decoration: BoxDecoration(
              color: AppColors.heatmapBg,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            ),
            child: Stack(
              children: const [
                Center(
                  child: Icon(
                    Icons.accessibility_new_rounded,
                    size: 112,
                    color: AppColors.heatmapInactive,
                  ),
                ),
                _HeatPoint(
                  label: '가슴 68%',
                  top: 54,
                  left: 92,
                  color: AppColors.heatmapHigh,
                ),
                _HeatPoint(
                  label: '왼쪽 어깨 42%',
                  top: 72,
                  left: 42,
                  color: AppColors.heatmapNormal,
                ),
                _HeatPoint(
                  label: '오른쪽 어깨 39%',
                  top: 72,
                  right: 42,
                  color: AppColors.heatmapNormal,
                ),
                _HeatPoint(
                  label: '삼두 54%',
                  top: 118,
                  right: 56,
                  color: AppColors.heatmapHigh,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeatPoint extends StatelessWidget {
  const _HeatPoint({
    required this.label,
    required this.top,
    required this.color,
    this.left,
    this.right,
  });

  final String label;
  final double top;
  final double? left;
  final double? right;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
          border: Border.all(color: color),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.card,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SessionCommentCard extends StatelessWidget {
  const _SessionCommentCard();

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('세션 코멘트', style: AppTextStyles.label),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '마지막 세트에서 보상동작이 증가했어요. 다음 운동에서는 몸의 중심선을 조금 더 안정적으로 유지해 보세요.',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SetResult {
  const _SetResult({
    required this.index,
    required this.targetReps,
    required this.actualReps,
    required this.speed,
  });

  final int index;
  final int targetReps;
  final int actualReps;
  final String speed;
}

const _setResults = [
  _SetResult(index: 1, targetReps: 12, actualReps: 12, speed: '보통'),
  _SetResult(index: 2, targetReps: 12, actualReps: 12, speed: '보통'),
  _SetResult(index: 3, targetReps: 10, actualReps: 9, speed: '느림'),
];
