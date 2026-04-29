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
      title: 'History',
      subtitle: 'Workout records',
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MonthSummaryCard(),
          const SizedBox(height: AppSpacing.sectionGap),
          Row(
            children: [
              Text('Recent sessions', style: AppTextStyles.sectionTitle),
              const Spacer(),
              const ImoChip(
                label: 'started_at DESC',
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
              Text('April summary', style: AppTextStyles.label),
              const Spacer(),
              const StatusBadge(label: '3 sessions', variant: StatusVariant.info),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Row(
            children: [
              Expanded(child: _SummaryMetric(label: 'Sessions', value: '3')),
              Expanded(child: _SummaryMetric(label: 'Reps', value: '96')),
              Expanded(child: _SummaryMetric(label: 'Minutes', value: '22')),
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
                      variant: session.status == 'completed'
                          ? StatusVariant.success
                          : StatusVariant.warning,
                      showDot: false,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${session.startedAt} · ${session.totalReps} reps · ${session.duration}',
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
              'Later this screen will query SQLite by started_at and exercise_type + started_at indexes.',
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
    exerciseName: 'Push-up',
    startedAt: 'Apr 27, 09:28',
    duration: '7m 12s',
    totalReps: 33,
    status: 'completed',
  ),
  _HistorySession(
    id: 'sess_20260425_001',
    exerciseName: 'Lateral raise',
    startedAt: 'Apr 25, 20:10',
    duration: '8m 40s',
    totalReps: 36,
    status: 'completed',
  ),
  _HistorySession(
    id: 'sess_20260422_001',
    exerciseName: 'Bicep curl',
    startedAt: 'Apr 22, 18:42',
    duration: '6m 50s',
    totalReps: 27,
    status: 'stopped',
  ),
];
