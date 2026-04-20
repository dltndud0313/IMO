import 'package:flutter/material.dart';

import '../models/exercise.dart';
import '../theme/app_theme.dart';
import '../widgets/exercise_icon.dart';
import 'calibration_screen.dart';

/// 운동 시작 전 자세 가이드 + 주의사항 화면.
class ExerciseGuideScreen extends StatelessWidget {
  final Exercise exercise;
  final Color accentColor;
  const ExerciseGuideScreen({
    super.key,
    required this.exercise,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(exercise.name)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // 운동 일러스트 (현재는 아이콘, 나중에 GIF/이미지 교체 가능)
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: ExerciseIcon(
                        exerciseId: exercise.id,
                        size: 140,
                        color: accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 운동 설명
                  Text(
                    exercise.description,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 타겟 근육
                  if (exercise.targetMuscle.isNotEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.fitness_center,
                                color: accentColor, size: 20),
                            const SizedBox(width: 10),
                            const Text(
                              '타겟 근육',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            Flexible(
                              child: Text(
                                exercise.targetMuscle,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),

                  // 자세 가이드
                  if (exercise.steps.isNotEmpty) ...[
                    _SectionTitle(
                      icon: Icons.check_circle_outline,
                      label: '자세 가이드',
                      color: accentColor,
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 16),
                        child: Column(
                          children: [
                            for (var i = 0; i < exercise.steps.length; i++)
                              _StepRow(
                                index: i + 1,
                                text: exercise.steps[i],
                                color: accentColor,
                                isLast: i == exercise.steps.length - 1,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 주의사항
                  if (exercise.cautions.isNotEmpty) ...[
                    const _SectionTitle(
                      icon: Icons.warning_amber_rounded,
                      label: '주의사항',
                      color: AppTheme.accent,
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final c in exercise.cautions)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '•  ',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: AppTheme.accent,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        c,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),

            // 하단 시작 버튼
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CalibrationScreen(exercise: exercise),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                ),
                icon: const Icon(Icons.play_arrow),
                label: const Text('운동 시작'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionTitle({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  final int index;
  final String text;
  final Color color;
  final bool isLast;
  const _StepRow({
    required this.index,
    required this.text,
    required this.color,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$index',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: color.withValues(alpha: 0.3),
                    margin: const EdgeInsets.symmetric(vertical: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 4, bottom: isLast ? 8 : 16),
              child: Text(
                text,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
