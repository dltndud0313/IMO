import 'package:flutter/material.dart';

import '../mock/mock_data.dart';
import '../models/exercise.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../widgets/exercise_icon.dart';
import '../widgets/ui/section_card.dart';
import 'exercise_guide_screen.dart';

class ExerciseSelectScreen extends StatelessWidget {
  final AppMode mode;
  const ExerciseSelectScreen({super.key, required this.mode});

  String get _title => mode == AppMode.workout ? '운동 선택' : '재활 동작 선택';
  LinearGradient get _gradient =>
      mode == AppMode.workout ? AppGradients.action : AppGradients.rehab;
  Color get _accentColor =>
      mode == AppMode.workout ? AppTheme.accent : AppTheme.rehab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final exercises = MockData.getExercises(mode);

    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.space20,
            AppTokens.space8,
            AppTokens.space20,
            AppTokens.space20,
          ),
          child: exercises.isEmpty
              ? _EmptyState(mode: mode)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      mode == AppMode.workout
                          ? '어떤 운동을\n하시겠어요?'
                          : '어떤 동작을\n진행하시겠어요?',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppTokens.space8),
                    Text(
                      '${exercises.length}개의 동작',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? AppTheme.textSecondaryDark
                            : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppTokens.space24),
                    Expanded(
                      child: ListView.separated(
                        itemCount: exercises.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppTokens.space12),
                        itemBuilder: (context, index) {
                          final ex = exercises[index];
                          return _ExerciseCard(
                            exercise: ex,
                            gradient: _gradient,
                            accentColor: _accentColor,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ExerciseGuideScreen(
                                    exercise: ex,
                                    accentColor: _accentColor,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppMode mode;
  const _EmptyState({required this.mode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: (isDark ? AppTheme.cardDark : AppTheme.card),
              shape: BoxShape.circle,
              boxShadow: AppTokens.shadowSoft(),
            ),
            child: Icon(
              Icons.hourglass_empty_rounded,
              size: 40,
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTokens.space20),
          Text(
            mode == AppMode.rehab ? '재활 동작 준비 중' : '준비 중',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppTokens.space4),
          Text(
            '곧 추가될 예정이에요',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final LinearGradient gradient;
  final Color accentColor;
  final VoidCallback onTap;

  const _ExerciseCard({
    required this.exercise,
    required this.gradient,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return SectionCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppTokens.space16),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              boxShadow: AppTokens.shadowGlow(gradient.colors.first),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: ExerciseIcon(
                exerciseId: exercise.id,
                size: 40,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: AppTokens.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  exercise.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: isDark
                ? AppTheme.textSecondaryDark
                : AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }
}
