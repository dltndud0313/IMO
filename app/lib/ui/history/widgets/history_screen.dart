import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '기록',
      subtitle: '운동 기록',
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MonthSummaryCard(),
          const SizedBox(height: AppSpacing.sectionGap),
          Row(
            children: [
              Text('최근 운동', style: AppTextStyles.sectionTitle),
              const Spacer(),
              const ImoChip(
                label: '최신순',
                variant: ImoChipVariant.outline,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final session in _sessions) ...[
            _SessionListTile(
              session: session,
              onTap: () => context.go('/history-detail?session=${session.id}'),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.md),
          const _HistoryQueryNotice(),
        ],
      ),
    );
  }
}

class _MonthSummaryCard extends StatelessWidget {
  const _MonthSummaryCard();

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      variant: ImoCardVariant.hero,
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                color: AppColors.primaryStrong,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text('4월 요약', style: AppTextStyles.label),
              const Spacer(),
              const StatusBadge(label: '3회 운동', variant: StatusVariant.info),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Row(
            children: [
              Expanded(child: _SummaryMetric(label: '운동', value: '3')),
              Expanded(child: _SummaryMetric(label: '횟수', value: '96')),
              Expanded(child: _SummaryMetric(label: '시간', value: '22분')),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: AppSpacing.xxs),
        Text(value, style: AppTextStyles.metric),
      ],
    );
  }
}

class _SessionListTile extends StatelessWidget {
  const _SessionListTile({
    required this.session,
    required this.onTap,
  });

  final _HistorySession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final completed = session.status == '정상 완료';

    return ImoCard(
      interactive: true,
      onTap: onTap,
      paddingSize: ImoCardPadding.lg,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              color: AppColors.primaryStrong,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        session.exerciseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.label.copyWith(fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    StatusBadge(
                      label: session.status,
                      variant: completed ? StatusVariant.success : StatusVariant.warning,
                      showDot: false,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${session.startedAt} · ${session.totalReps}회 · ${session.duration}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }
}

class _HistoryQueryNotice extends StatelessWidget {
  const _HistoryQueryNotice();

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      variant: ImoCardVariant.subtle,
      paddingSize: ImoCardPadding.lg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.storage_rounded,
            color: AppColors.primaryStrong,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '추후 SQLite의 started_at, exercise_type + started_at 인덱스를 기준으로 기록을 조회합니다.',
              style: AppTextStyles.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistorySession {
  const _HistorySession({
    required this.id,
    required this.exerciseName,
    required this.startedAt,
    required this.duration,
    required this.totalReps,
    required this.status,
  });

  final String id;
  final String exerciseName;
  final String startedAt;
  final String duration;
  final int totalReps;
  final String status;
}

const _sessions = [
  _HistorySession(
    id: 'sess_20260427_001',
    exerciseName: '푸시업',
    startedAt: '4월 27일 09:28',
    duration: '7분 12초',
    totalReps: 33,
    status: '정상 완료',
  ),
  _HistorySession(
    id: 'sess_20260425_001',
    exerciseName: '사이드 레터럴 레이즈',
    startedAt: '4월 25일 20:10',
    duration: '8분 40초',
    totalReps: 36,
    status: '정상 완료',
  ),
  _HistorySession(
    id: 'sess_20260422_001',
    exerciseName: '바이셉 컬',
    startedAt: '4월 22일 18:42',
    duration: '6분 50초',
    totalReps: 27,
    status: '중단',
  ),
];
