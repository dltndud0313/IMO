import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/dependencies.dart';
import '../../../data/repositories/workout_repository.dart';
import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';
import '../view_model/workout_setup_viewmodel.dart';

class PlanSettingScreen extends StatefulWidget {
  const PlanSettingScreen({super.key, this.exerciseId = 'pushup'});

  final String exerciseId;

  @override
  State<PlanSettingScreen> createState() => _PlanSettingScreenState();
}

class _PlanSettingScreenState extends State<PlanSettingScreen> {
  int _setCount = 3;
  List<int> _targetRepsPerSet = [12, 12, 10];
  int _restSeconds = 60;
  bool _submitting = false;
  bool _perSetMode = false;
  late final WorkoutSetupViewModel _viewModel;

  int get _totalReps => _targetRepsPerSet.fold(0, (sum, reps) => sum + reps);

  int get _estimatedMinutes =>
      ((_totalReps * 3 + _restSeconds * (_setCount - 1)) / 60).ceil();

  @override
  void initState() {
    super.initState();
    _viewModel = WorkoutSetupViewModel(getIt<WorkoutRepository>());
  }

  void _syncSetCount(int nextCount) {
    setState(() {
      _setCount = nextCount;
      if (_targetRepsPerSet.length < nextCount) {
        _targetRepsPerSet = [
          ..._targetRepsPerSet,
          ...List<int>.filled(nextCount - _targetRepsPerSet.length, 10),
        ];
      } else {
        _targetRepsPerSet = _targetRepsPerSet.take(nextCount).toList();
      }
    });
  }

  void _changeAllReps(int delta) {
    setState(() {
      _targetRepsPerSet = [
        for (final reps in _targetRepsPerSet) (reps + delta).clamp(1, 50),
      ];
    });
  }

  void _changeSetReps(int index, int delta) {
    setState(() {
      final nextReps = [..._targetRepsPerSet];
      nextReps[index] = (nextReps[index] + delta).clamp(1, 50);
      _targetRepsPerSet = nextReps;
    });
  }

  void _togglePerSetMode() {
    setState(() {
      if (_perSetMode) {
        final reps = _targetRepsPerSet.first;
        _targetRepsPerSet = List<int>.filled(_setCount, reps);
      }
      _perSetMode = !_perSetMode;
    });
  }

  Future<void> _submitPlan() async {
    setState(() => _submitting = true);
    try {
      final result = await _viewModel.submitWorkoutPlan(
        exerciseType: widget.exerciseId,
        setCount: _setCount,
        targetRepsPerSet: _targetRepsPerSet,
        restSec: _restSeconds,
      );
      if (!result.accepted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.validationErrors.join(', '))),
          );
        }
        return;
      }
      if (mounted) {
        context.go('/sensor-guide?exercise=${widget.exerciseId}');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Pi connection failed.')));
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '운동 계획 설정',
      showBackButton: true,
      onBack: () => context.go('/workout-guide?exercise=${widget.exerciseId}'),
      scrollable: true,
      bottom: ImoButton(
        label: '다음',
        loading: _submitting,
        disabled: _submitting,
        onPressed: _submitPlan,
      ),
      body: Column(
        children: [
          _SettingCard(
            title: '세트 수',
            description: '최대 10세트',
            value: _setCount,
            suffix: '',
            onDecrease: () => _syncSetCount((_setCount - 1).clamp(1, 10)),
            onIncrease: () => _syncSetCount((_setCount + 1).clamp(1, 10)),
          ),
          const SizedBox(height: AppSpacing.md),
          _SettingCard(
            title: '세트당 목표 횟수',
            description: _perSetMode ? '세트별로 각각 설정' : '모든 세트 동일',
            value: _targetRepsPerSet.first,
            suffix: '',
            chipLabel: _perSetMode ? '전체 동일' : '세트별',
            chipSelected: _perSetMode,
            onChipTap: _togglePerSetMode,
            onDecrease: () => _changeAllReps(-1),
            onIncrease: () => _changeAllReps(1),
            showCounter: !_perSetMode,
          ),
          if (_perSetMode) ...[
            const SizedBox(height: AppSpacing.sm),
            _PerSetRepsCard(
              repsPerSet: _targetRepsPerSet,
              onDecrease: (index) => _changeSetReps(index, -1),
              onIncrease: (index) => _changeSetReps(index, 1),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _SettingCard(
            title: '세트 간 휴식',
            description: '30 ~ 300초',
            value: _restSeconds,
            suffix: '초',
            onDecrease: () => setState(
              () => _restSeconds = (_restSeconds - 15).clamp(30, 300),
            ),
            onIncrease: () => setState(
              () => _restSeconds = (_restSeconds + 15).clamp(30, 300),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _PlanTotalCard(
            setCount: _setCount,
            totalReps: _totalReps,
            estimatedMinutes: _estimatedMinutes,
          ),
        ],
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({
    required this.title,
    required this.description,
    required this.value,
    required this.suffix,
    required this.onDecrease,
    required this.onIncrease,
    this.chipLabel,
    this.chipSelected = false,
    this.onChipTap,
    this.showCounter = true,
  });

  final String title;
  final String description;
  final int value;
  final String suffix;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final String? chipLabel;
  final bool chipSelected;
  final VoidCallback? onChipTap;
  final bool showCounter;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      paddingSize: ImoCardPadding.lg,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyLg.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(description, style: AppTextStyles.body),
                if (chipLabel != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  ImoChip(
                    label: chipLabel!,
                    selected: chipSelected,
                    variant: ImoChipVariant.defaultChip,
                    icon: const Icon(Icons.tune_rounded, size: 14),
                    onTap: onChipTap,
                  ),
                ],
              ],
            ),
          ),
          if (showCounter) ...[
            const SizedBox(width: AppSpacing.sm),
            _RoundButton(
              icon: Icons.remove_rounded,
              color: AppColors.cardSubtle,
              iconColor: AppColors.textPrimary,
              onTap: onDecrease,
            ),
            SizedBox(
              width: suffix.isEmpty ? 48 : 64,
              child: Text.rich(
                TextSpan(
                  text: '$value',
                  children: [
                    if (suffix.isNotEmpty)
                      TextSpan(
                        text: ' $suffix',
                        style: AppTextStyles.bodySmall,
                      ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: AppTextStyles.sectionTitle,
              ),
            ),
            _RoundButton(
              icon: Icons.add_rounded,
              color: AppColors.primary,
              iconColor: AppColors.card,
              onTap: onIncrease,
            ),
          ],
        ],
      ),
    );
  }
}

class _PerSetRepsCard extends StatelessWidget {
  const _PerSetRepsCard({
    required this.repsPerSet,
    required this.onDecrease,
    required this.onIncrease,
  });

  final List<int> repsPerSet;
  final ValueChanged<int> onDecrease;
  final ValueChanged<int> onIncrease;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      variant: ImoCardVariant.outlined,
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('세트별 목표 횟수', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.md),
          for (var index = 0; index < repsPerSet.length; index++) ...[
            _PerSetRepsRow(
              index: index,
              reps: repsPerSet[index],
              onDecrease: () => onDecrease(index),
              onIncrease: () => onIncrease(index),
            ),
            if (index != repsPerSet.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _PerSetRepsRow extends StatelessWidget {
  const _PerSetRepsRow({
    required this.index,
    required this.reps,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int index;
  final int reps;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text('${index + 1}세트', style: AppTextStyles.bodyLg)),
        _RoundButton(
          icon: Icons.remove_rounded,
          color: AppColors.cardSubtle,
          iconColor: AppColors.textPrimary,
          onTap: onDecrease,
        ),
        SizedBox(
          width: 52,
          child: Text(
            '$reps',
            textAlign: TextAlign.center,
            style: AppTextStyles.sectionTitle,
          ),
        ),
        _RoundButton(
          icon: Icons.add_rounded,
          color: AppColors.primary,
          iconColor: AppColors.card,
          onTap: onIncrease,
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: iconColor, size: 22),
        ),
      ),
    );
  }
}

class _PlanTotalCard extends StatelessWidget {
  const _PlanTotalCard({
    required this.setCount,
    required this.totalReps,
    required this.estimatedMinutes,
  });

  final int setCount;
  final int totalReps;
  final int estimatedMinutes;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      variant: ImoCardVariant.subtle,
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('요약', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.md),
          _SummaryLine(label: '총 세트', value: '$setCount세트'),
          const SizedBox(height: AppSpacing.xs),
          _SummaryLine(label: '총 횟수', value: '$totalReps회'),
          const SizedBox(height: AppSpacing.xs),
          _SummaryLine(label: '예상 소요', value: '약 $estimatedMinutes분'),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: AppTextStyles.bodyLg),
        const Spacer(),
        Text(value, style: AppTextStyles.label.copyWith(fontSize: 16)),
      ],
    );
  }
}
