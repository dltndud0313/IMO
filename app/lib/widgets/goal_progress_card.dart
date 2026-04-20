import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 주간 목표 달성률 카드.
class GoalProgressCard extends StatelessWidget {
  final int sessionCount;
  final int sessionGoal;
  final int repCount;
  final int repGoal;

  const GoalProgressCard({
    super.key,
    required this.sessionCount,
    required this.sessionGoal,
    required this.repCount,
    required this.repGoal,
  });

  @override
  Widget build(BuildContext context) {
    final sessionPct = sessionGoal > 0
        ? (sessionCount / sessionGoal).clamp(0.0, 1.0)
        : 0.0;
    final repPct =
        repGoal > 0 ? (repCount / repGoal).clamp(0.0, 1.0) : 0.0;
    final sessionDone = sessionCount >= sessionGoal;
    final repDone = repCount >= repGoal;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flag_rounded,
                    size: 18, color: AppTheme.primary),
                const SizedBox(width: 6),
                const Text(
                  '이번 주 목표',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (sessionDone && repDone)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '달성!',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.success,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _GoalRow(
              label: '운동 횟수',
              current: sessionCount,
              goal: sessionGoal,
              pct: sessionPct,
              done: sessionDone,
            ),
            const SizedBox(height: 12),
            _GoalRow(
              label: '반복 횟수',
              current: repCount,
              goal: repGoal,
              pct: repPct,
              done: repDone,
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  final String label;
  final int current;
  final int goal;
  final double pct;
  final bool done;

  const _GoalRow({
    required this.label,
    required this.current,
    required this.goal,
    required this.pct,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final color = done ? AppTheme.success : AppTheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary)),
            const Spacer(),
            Text('$current',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color)),
            Text(' / $goal',
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: AppTheme.border,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}
