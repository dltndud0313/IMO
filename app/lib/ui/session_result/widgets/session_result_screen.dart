import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/dependencies.dart';
import '../../../data/repositories/session_history_repository.dart';
import '../../../domain/models/exercise_type.dart';
import '../../../domain/models/set_result.dart';
import '../../../domain/models/workout_session.dart';
import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';

class SessionResultScreen extends StatefulWidget {
  const SessionResultScreen({
    super.key,
    required this.sessionId,
    this.initialSession,
  });

  final String sessionId;
  final WorkoutSession? initialSession;

  @override
  State<SessionResultScreen> createState() => _SessionResultScreenState();
}

class _SessionResultScreenState extends State<SessionResultScreen> {
  late final Future<WorkoutSession?> _future;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSession;
    if (initial != null) {
      _future = Future.value(initial);
    } else if (widget.sessionId.isEmpty) {
      _future = Future.value(null);
    } else {
      _future = getIt<SessionHistoryRepository>()
          .getSessionDetail(widget.sessionId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '운동 결과',
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
      body: FutureBuilder<WorkoutSession?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _ResultInfo(message: '결과를 불러오는 중입니다.');
          }
          if (snapshot.hasError) {
            return const _ResultInfo(message: '결과를 불러오지 못했습니다.');
          }
          final session = snapshot.data;
          if (session == null) {
            return const _ResultInfo(
              message: '저장된 운동 결과가 없습니다.\n비상 종료된 운동은 결과가 저장되지 않을 수 있어요.',
            );
          }
          return _ResultContent(session: session);
        },
      ),
    );
  }
}

class _ResultInfo extends StatelessWidget {
  const _ResultInfo({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      paddingSize: ImoCardPadding.lg,
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _ResultContent extends StatelessWidget {
  const _ResultContent({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final hasMuscleMap =
        session.muscleMap != null && session.muscleMap!.values.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ResultHeroCard(session: session),
        const SizedBox(height: AppSpacing.sectionGap),
        _ResultMetricGrid(session: session),
        const SizedBox(height: AppSpacing.md),
        _SetResultsCard(setResults: session.setResults),
        if (hasMuscleMap) ...[
          const SizedBox(height: AppSpacing.md),
          _MuscleActivityCard(
            muscleMap: session.muscleMap!.values,
            exerciseType: session.exerciseType,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        _SessionCommentCard(comment: session.comment),
      ],
    );
  }
}

class _ResultHeroCard extends StatelessWidget {
  const _ResultHeroCard({required this.session});

  final WorkoutSession session;

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
          Text(
            '${session.exerciseType.label} 완료',
            style: AppTextStyles.title,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '운동 결과가 저장되었어요. 기록에서 다시 확인할 수 있습니다.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body,
          ),
        ],
      ),
    );
  }
}

class _ResultMetricGrid extends StatelessWidget {
  const _ResultMetricGrid({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final minutes = session.durationSec ~/ 60;
    final seconds = session.durationSec % 60;
    final durationLabel =
        minutes > 0 ? '$minutes분 $seconds초' : '$seconds초';

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.42,
      children: [
        _MetricTile(
          icon: Icons.fitness_center_rounded,
          label: '총 횟수',
          value: '${session.totalReps}',
          tint: AppColors.primary,
        ),
        _MetricTile(
          icon: Icons.check_circle_rounded,
          label: '유효 횟수',
          value: '${session.validReps}',
          tint: AppColors.success,
        ),
        _MetricTile(
          icon: Icons.timer_rounded,
          label: '운동 시간',
          value: durationLabel,
          tint: AppColors.warning,
        ),
        _MetricTile(
          icon: Icons.warning_amber_rounded,
          label: '보상동작',
          value: '${session.compensationCount}',
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
  const _SetResultsCard({required this.setResults});

  final List<SetResult> setResults;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('세트별 결과', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.md),
          if (setResults.isEmpty)
            Text(
              '세트 기록이 없습니다.',
              style:
                  AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            )
          else
            for (var i = 0; i < setResults.length; i++) ...[
              _SetResultRow(result: setResults[i]),
              if (i < setResults.length - 1)
                const SizedBox(height: AppSpacing.sm),
            ],
        ],
      ),
    );
  }
}

class _SetResultRow extends StatelessWidget {
  const _SetResultRow({required this.result});

  final SetResult result;

  @override
  Widget build(BuildContext context) {
    final completed = result.actualReps >= result.targetReps;

    return ImoCard(
      variant:
          completed ? ImoCardVariant.subtle : ImoCardVariant.outlined,
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
              '${result.setIndex}',
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
                Text('${result.setIndex}세트', style: AppTextStyles.label),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${result.actualReps}/${result.targetReps}회 · ${_formatSpeed(result.avgSpeed)}',
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

  static String _formatSpeed(String avgSpeed) {
    return switch (avgSpeed.toLowerCase()) {
      'fast' => '빠름',
      'slow' => '느림',
      'normal' => '보통',
      _ => avgSpeed,
    };
  }
}

class _MuscleActivityCard extends StatelessWidget {
  const _MuscleActivityCard({
    required this.muscleMap,
    required this.exerciseType,
  });

  final Map<String, double> muscleMap;
  final ExerciseType exerciseType;

  @override
  Widget build(BuildContext context) {
    final entries = _buildEntries(muscleMap, exerciseType);
    return ImoCard(
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.show_chart_rounded,
                size: 18,
                color: AppColors.primaryStrong,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text('근육 활성도', style: AppTextStyles.label),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (entries.isEmpty)
            Text(
              '근육 활성도 데이터가 없습니다.',
              style:
                  AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            )
          else ...[
            for (var i = 0; i < entries.length; i++) ...[
              _ActivityBar(entry: entries[i]),
              if (i < entries.length - 1)
                const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.md),
            const _ActivityLegend(),
          ],
        ],
      ),
    );
  }

  // NOTE: 현재 Pi가 실제 송신하는 키(`chest`, `left_shoulder` 등)를 직접 사용.
  // Pi 코드에 데이터 손실 버그가 있어 일부 채널이 muscle_map에 안 들어옴
  // (예: lateral_raise의 상부 승모근). 자세한 내용 및 수정 명세:
  // docs/pi_muscle_map_alignment.md
  // Pi 수정 완료 후 매핑 키를 schema 기준(left_chest, left_lateral_deltoid 등)으로
  // update하는 follow-up 커밋 필요.
  static List<_MuscleEntry> _buildEntries(
    Map<String, double> map,
    ExerciseType exerciseType,
  ) {
    final entries = <_MuscleEntry>[];
    void addAvg(String label, List<String> keys) {
      final present = keys.where(map.containsKey).toList();
      if (present.isEmpty) return;
      final avg =
          present.fold<double>(0, (sum, k) => sum + (map[k] ?? 0)) /
              present.length;
      entries.add(_MuscleEntry(label: label, pct: avg));
    }

    switch (exerciseType) {
      case ExerciseType.pushUp:
        addAvg('대흉근', ['chest']);
        addAvg('어깨', ['left_shoulder', 'right_shoulder']);
        addAvg('삼두근', ['left_triceps', 'right_triceps']);
      case ExerciseType.lateralRaise:
        addAvg('측면 삼각근', ['left_shoulder', 'right_shoulder']);
        addAvg('승모근', ['left_upper_trapezius', 'right_upper_trapezius']);
      case ExerciseType.bicepCurl:
        addAvg('이두근', ['left_biceps', 'right_biceps']);
        addAvg('전완근', ['left_forearm', 'right_forearm']);
    }

    return entries;
  }
}

class _ActivityBar extends StatelessWidget {
  const _ActivityBar({required this.entry});

  final _MuscleEntry entry;

  @override
  Widget build(BuildContext context) {
    final classification = _classifyActivity(entry.pct);
    final fraction = (entry.pct / 100).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(entry.label, style: AppTextStyles.body),
            const Spacer(),
            Text(
              '${entry.pct.toStringAsFixed(0)}% · ${classification.label}',
              style: AppTextStyles.caption,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: AppColors.disabledBg,
            valueColor: AlwaysStoppedAnimation(classification.color),
          ),
        ),
      ],
    );
  }
}

class _ActivityLegend extends StatelessWidget {
  const _ActivityLegend();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendDot(color: AppColors.primary, label: '낮음'),
        SizedBox(width: AppSpacing.md),
        _LegendDot(color: AppColors.success, label: '보통'),
        SizedBox(width: AppSpacing.md),
        _LegendDot(color: AppColors.warning, label: '높음'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xxs),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}

class _MuscleEntry {
  const _MuscleEntry({required this.label, required this.pct});

  final String label;
  final double pct;
}

class _ActivityClassification {
  const _ActivityClassification({required this.label, required this.color});

  final String label;
  final Color color;
}

_ActivityClassification _classifyActivity(double pct) {
  if (pct >= 70) {
    return const _ActivityClassification(
      label: '높음',
      color: AppColors.warning,
    );
  }
  if (pct >= 40) {
    return const _ActivityClassification(
      label: '보통',
      color: AppColors.success,
    );
  }
  return const _ActivityClassification(
    label: '낮음',
    color: AppColors.primary,
  );
}

class _SessionCommentCard extends StatelessWidget {
  const _SessionCommentCard({required this.comment});

  final String? comment;

  @override
  Widget build(BuildContext context) {
    final trimmed = comment?.trim();
    final hasComment = trimmed != null && trimmed.isNotEmpty;
    final message = hasComment
        ? trimmed
        : '오늘 운동 데이터가 잘 저장되었어요. 기록 탭에서 더 자세히 확인해보세요.';

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
                Text(message, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
