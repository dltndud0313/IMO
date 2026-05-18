import 'package:flutter/material.dart';

import '../../../config/dependencies.dart';
import '../../../data/repositories/session_history_repository.dart';
import '../../../domain/models/muscle_map_schema.dart';
import '../../../domain/models/workout_session.dart';
import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';

class HistoryDetailScreen extends StatefulWidget {
  const HistoryDetailScreen({super.key, this.date = ''});

  final String date;

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  late final Future<List<WorkoutSession>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadDay();
  }

  Future<List<WorkoutSession>> _loadDay() async {
    final repo = getIt<SessionHistoryRepository>();
    final summaries = await repo.getSessionsByDate(widget.date);
    if (summaries.isEmpty) {
      return const [];
    }
    return Future.wait(
      summaries.map((s) => repo.getSessionDetail(s.sessionId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '하루 운동 상세',
      showBackButton: true,
      scrollable: true,
      body: FutureBuilder<List<WorkoutSession>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _DetailInfo(message: '데이터를 불러오는 중입니다.');
          }
          if (snapshot.hasError) {
            return const _DetailInfo(message: '데이터를 불러오지 못했습니다.');
          }
          final sessions = snapshot.data ?? const <WorkoutSession>[];
          if (sessions.isEmpty) {
            return const _DetailInfo(message: '해당 날짜의 기록이 없습니다.');
          }
          return _DayDetailContent(date: widget.date, sessions: sessions);
        },
      ),
    );
  }
}

class _DetailInfo extends StatelessWidget {
  const _DetailInfo({required this.message});

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

class _DayDetailContent extends StatelessWidget {
  const _DayDetailContent({required this.date, required this.sessions});

  final String date;
  final List<WorkoutSession> sessions;

  @override
  Widget build(BuildContext context) {
    final muscleAggregate = _aggregateMuscleMap(sessions);
    final muscleEntries = _buildMuscleEntries(muscleAggregate);
    final balanceItems = _buildBalanceItems(muscleAggregate);
    final compensations = sessions.fold<int>(
      0,
      (sum, s) => sum + s.compensationCount,
    );
    final fatigueOnset = _findEarliestFatigue(sessions);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (muscleEntries.isNotEmpty)
          _MuscleActivityCard(entries: muscleEntries)
        else
          const _EmptySectionCard(
            icon: Icons.show_chart_rounded,
            title: '근육 활성도',
            message: '근육 활성도 데이터가 없습니다.',
          ),
        const SizedBox(height: AppSpacing.md),
        if (balanceItems.isNotEmpty)
          _BalanceCard(items: balanceItems)
        else
          const _EmptySectionCard(
            icon: Icons.trending_up_rounded,
            title: '좌우 밸런스',
            message: '좌우 밸런스 데이터가 없습니다.',
          ),
        if (compensations > 0 || fatigueOnset != null) ...[
          const SizedBox(height: AppSpacing.md),
          _PostureFatigueCard(
            compensations: compensations,
            fatigueOnset: fatigueOnset,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text('운동별 기록', style: AppTextStyles.sectionTitle),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < sessions.length; i++) ...[
          _ExerciseRow(session: sessions[i]),
          if (i < sessions.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _MuscleActivityCard extends StatelessWidget {
  const _MuscleActivityCard({required this.entries});

  final List<_MuscleEntry> entries;

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
                Icons.show_chart_rounded,
                size: 18,
                color: AppColors.primaryStrong,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text('근육 활성도', style: AppTextStyles.label),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < entries.length; i++) ...[
            _ActivityBar(entry: entries[i]),
            if (i < entries.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.md),
          const _ActivityLegend(),
        ],
      ),
    );
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

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.items});

  final List<_BalanceItem> items;

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
                Icons.trending_up_rounded,
                size: 18,
                color: AppColors.primaryStrong,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text('좌우 밸런스', style: AppTextStyles.label),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < items.length; i++) ...[
            _BalanceRow(item: items[i]),
            if (i < items.length - 1)
              const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.item});

  final _BalanceItem item;

  @override
  Widget build(BuildContext context) {
    final status = _balanceStatus(item.leftPct, item.rightPct);
    final color = _balanceStatusColor(status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(item.label, style: AppTextStyles.body),
            const Spacer(),
            _BalanceStatusBadge(status: status),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '좌 ${item.leftPct.toStringAsFixed(0)}% · 우 ${item.rightPct.toStringAsFixed(0)}%',
              style: AppTextStyles.caption,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        // 회색 트랙 위에 중앙 기준으로 좌/우 값(0~100%) 만큼 양방향으로 자라는
        // 막대. 좌/우 길이를 직관적으로 비교할 수 있고, 가운데에 1px 흰 분리선.
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
          child: SizedBox(
            height: 10,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final halfWidth = constraints.maxWidth / 2;
                final leftFill =
                    (item.leftPct / 100.0).clamp(0.0, 1.0) * halfWidth;
                final rightFill =
                    (item.rightPct / 100.0).clamp(0.0, 1.0) * halfWidth;
                return Stack(
                  children: [
                    const Positioned.fill(
                      child: ColoredBox(color: AppColors.disabledBg),
                    ),
                    Positioned(
                      left: halfWidth - leftFill,
                      top: 0,
                      bottom: 0,
                      width: leftFill,
                      child: ColoredBox(color: color),
                    ),
                    Positioned(
                      left: halfWidth,
                      top: 0,
                      bottom: 0,
                      width: rightFill,
                      child: ColoredBox(color: color),
                    ),
                    Positioned(
                      left: halfWidth - 0.5,
                      top: 0,
                      bottom: 0,
                      width: 1,
                      child: const ColoredBox(color: AppColors.card),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

enum _BalanceStatusLevel { balanced, mild, significant }

// 백엔드 _balance_status(ratio) 로직과 동일: ≥90 균형, ≥75 주의, 그 외 심각.
_BalanceStatusLevel _balanceStatus(double leftPct, double rightPct) {
  final maxV = leftPct > rightPct ? leftPct : rightPct;
  if (maxV <= 0) return _BalanceStatusLevel.balanced;
  final minV = leftPct < rightPct ? leftPct : rightPct;
  final ratio = minV / maxV * 100.0;
  if (ratio >= 90.0) return _BalanceStatusLevel.balanced;
  if (ratio >= 75.0) return _BalanceStatusLevel.mild;
  return _BalanceStatusLevel.significant;
}

Color _balanceStatusColor(_BalanceStatusLevel status) {
  switch (status) {
    case _BalanceStatusLevel.balanced:
      return AppColors.success;
    case _BalanceStatusLevel.mild:
      return AppColors.warning;
    case _BalanceStatusLevel.significant:
      return AppColors.error;
  }
}

class _BalanceStatusBadge extends StatelessWidget {
  const _BalanceStatusBadge({required this.status});

  final _BalanceStatusLevel status;

  @override
  Widget build(BuildContext context) {
    final color = _balanceStatusColor(status);
    final (icon, label) = switch (status) {
      _BalanceStatusLevel.balanced =>
        (Icons.check_circle_rounded, '균형'),
      _BalanceStatusLevel.mild =>
        (Icons.warning_amber_rounded, '주의'),
      _BalanceStatusLevel.significant =>
        (Icons.error_rounded, '심각'),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 2),
        Text(
          label,
          style: AppTextStyles.caption
              .copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _PostureFatigueCard extends StatelessWidget {
  const _PostureFatigueCard({
    required this.compensations,
    required this.fatigueOnset,
  });

  final int compensations;
  final ({int set, int rep})? fatigueOnset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.largeCardPadding),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text('자세·피로', style: AppTextStyles.label),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text('보상동작', style: AppTextStyles.body),
              const Spacer(),
              Text(
                '$compensations회',
                style: AppTextStyles.label.copyWith(color: AppColors.warning),
              ),
            ],
          ),
          if (fatigueOnset != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Text('피로 시작 시점', style: AppTextStyles.body),
                const Spacer(),
                Text(
                  '${fatigueOnset!.set}세트 ${fatigueOnset!.rep}회차',
                  style: AppTextStyles.label,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final minutes = (session.durationSec / 60).ceil();
    return ImoCard(
      paddingSize: ImoCardPadding.md,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              color: AppColors.primaryStrong,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.exerciseType.label,
                  style: AppTextStyles.label,
                ),
                const SizedBox(height: 2),
                Text(
                  '${session.setCount}세트 · ${session.totalReps}회 · $minutes분',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySectionCard extends StatelessWidget {
  const _EmptySectionCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primaryStrong),
              const SizedBox(width: AppSpacing.xs),
              Text(title, style: AppTextStyles.label),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _MuscleEntry {
  const _MuscleEntry({required this.label, required this.pct});

  final String label;
  final double pct;
}

class _BalanceItem {
  const _BalanceItem({
    required this.label,
    required this.leftPct,
    required this.rightPct,
  });

  final String label;
  final double leftPct;
  final double rightPct;
}

class _ActivityClassification {
  const _ActivityClassification({required this.label, required this.color});

  final String label;
  final Color color;
}

_ActivityClassification _classifyActivity(double pct) {
  if (pct >= 70) {
    return const _ActivityClassification(label: '높음', color: AppColors.warning);
  }
  if (pct >= 40) {
    return const _ActivityClassification(label: '보통', color: AppColors.success);
  }
  return const _ActivityClassification(label: '낮음', color: AppColors.primary);
}

Map<String, double> _aggregateMuscleMap(List<WorkoutSession> sessions) {
  final sums = <String, double>{};
  final counts = <String, int>{};
  for (final session in sessions) {
    final values = session.muscleMap?.values;
    if (values == null) continue;
    values.forEach((key, value) {
      sums[key] = (sums[key] ?? 0) + value;
      counts[key] = (counts[key] ?? 0) + 1;
    });
  }
  return {
    for (final key in sums.keys) key: sums[key]! / counts[key]!,
  };
}

List<_MuscleEntry> _buildMuscleEntries(Map<String, double> map) {
  if (map.isEmpty) return const [];
  final entries = <_MuscleEntry>[];
  void add(String label, List<String> keys) {
    final present = keys.where(map.containsKey).toList();
    if (present.isEmpty) return;
    final avg = present.fold<double>(0, (sum, k) => sum + map[k]!) /
        present.length;
    // 스케일 계약: 활성도는 전 구간 0~100 percent. clamp 만 하고 그대로 표시.
    entries.add(_MuscleEntry(label: label, pct: clampMuscleMapPercent(avg)));
  }

  // 키 명명은 app schema / Pi 송신 키와 정합 (docs/pi_muscle_map_alignment.md).
  // 옛 단일 chest 키는 마이그레이션 이전 데이터에만 존재 — 더 이상 노출하지 않음.
  add('대흉근', ['left_chest', 'right_chest']);
  add('측면 삼각근', ['left_lateral_deltoid', 'right_lateral_deltoid']);
  add('승모근', ['left_upper_trapezius', 'right_upper_trapezius']);
  add('삼두근', ['left_triceps', 'right_triceps']);
  add('이두근', ['left_biceps', 'right_biceps']);
  add('전완근', ['left_forearm', 'right_forearm']);
  return entries;
}

List<_BalanceItem> _buildBalanceItems(Map<String, double> map) {
  final items = <_BalanceItem>[];
  void add(String label, String leftKey, String rightKey) {
    final left = map[leftKey];
    final right = map[rightKey];
    if (left != null && right != null) {
      // 스케일 계약: 좌우 값 모두 0~100 percent. clamp 만 하고 그대로 표시.
      items.add(_BalanceItem(
        label: label,
        leftPct: clampMuscleMapPercent(left),
        rightPct: clampMuscleMapPercent(right),
      ));
    }
  }

  add('대흉근', 'left_chest', 'right_chest');
  add('측면 삼각근', 'left_lateral_deltoid', 'right_lateral_deltoid');
  add('승모근', 'left_upper_trapezius', 'right_upper_trapezius');
  add('삼두근', 'left_triceps', 'right_triceps');
  add('이두근', 'left_biceps', 'right_biceps');
  add('전완근', 'left_forearm', 'right_forearm');
  return items;
}

({int set, int rep})? _findEarliestFatigue(List<WorkoutSession> sessions) {
  ({int set, int rep})? earliest;
  for (final s in sessions) {
    final set = s.fatigueOnsetSet;
    final rep = s.fatigueOnsetRep;
    if (set == null || rep == null) continue;
    if (earliest == null ||
        set < earliest.set ||
        (set == earliest.set && rep < earliest.rep)) {
      earliest = (set: set, rep: rep);
    }
  }
  return earliest;
}
