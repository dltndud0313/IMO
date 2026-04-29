import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';

class PlanSettingScreen extends StatefulWidget {
  const PlanSettingScreen({
    super.key,
    this.exerciseId = 'pushup',
  });

  final String exerciseId;

  @override
  State<PlanSettingScreen> createState() => _PlanSettingScreenState();
}

class _PlanSettingScreenState extends State<PlanSettingScreen> {
  int _setCount = 3;
  int _restSeconds = 60;
  bool _perSetMode = false;
  List<int> _repsPerSet = [10, 10, 10];

  String get _exerciseTitle =>
      _exerciseNames[widget.exerciseId] ?? _exerciseNames['pushup']!;

  int get _totalReps =>
      _repsPerSet.take(_setCount).fold(0, (total, reps) => total + reps);

  int get _estimatedMinutes =>
      ((_totalReps * 3 + _restSeconds * (_setCount - 1)) / 60).ceil();

  void _updateSetCount(int value) {
    setState(() {
      _setCount = value.clamp(1, 10);
      final next = [..._repsPerSet];
      while (next.length < _setCount) {
        next.add(next.isEmpty ? 10 : next.last);
      }
      _repsPerSet = next.take(_setCount).toList();
    });
  }

  void _updateAllReps(int value) {
    setState(() {
      _repsPerSet = List.filled(_setCount, value.clamp(1, 50));
    });
  }

  void _updateSetReps(int index, int value) {
    setState(() {
      _repsPerSet[index] = value.clamp(1, 50);
    });
  }

  void _updateRestSeconds(int value) {
    setState(() {
      _restSeconds = value.clamp(30, 300);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _exerciseTitle,
      subtitle: 'Workout plan',
      showBackButton: true,
      scrollable: true,
      bottom: ImoButton(
        label: 'Continue',
        rightIcon: const Icon(Icons.arrow_forward_rounded),
        onPressed: () => context.go('/workout'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PlanSummaryHeader(
            exerciseTitle: _exerciseTitle,
            setCount: _setCount,
            totalReps: _totalReps,
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          _SetCountCard(
            value: _setCount,
            onChanged: _updateSetCount,
          ),
          const SizedBox(height: AppSpacing.md),
          _RepsCard(
            setCount: _setCount,
            perSetMode: _perSetMode,
            repsPerSet: _repsPerSet,
            onModeChanged: (value) => setState(() => _perSetMode = value),
            onAllRepsChanged: _updateAllReps,
            onSetRepsChanged: _updateSetReps,
          ),
          const SizedBox(height: AppSpacing.md),
          _RestTimeCard(
            value: _restSeconds,
            onChanged: _updateRestSeconds,
          ),
          const SizedBox(height: AppSpacing.md),
          _PlanTotalCard(
            setCount: _setCount,
            totalReps: _totalReps,
            restSeconds: _restSeconds,
            estimatedMinutes: _estimatedMinutes,
          ),
        ],
      ),
    );
  }
}

class _PlanSummaryHeader extends StatelessWidget {
  const _PlanSummaryHeader({
    required this.exerciseTitle,
    required this.setCount,
    required this.totalReps,
  });

  final String exerciseTitle;
  final int setCount;
  final int totalReps;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      variant: ImoCardVariant.hero,
      paddingSize: ImoCardPadding.lg,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryStrong],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: AppColors.card,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exerciseTitle, style: AppTextStyles.sectionTitle),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '$setCount sets · $totalReps target reps',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          const ImoChip(
            label: 'Draft',
            variant: ImoChipVariant.selected,
          ),
        ],
      ),
    );
  }
}

class _SetCountCard extends StatelessWidget {
  const _SetCountCard({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      paddingSize: ImoCardPadding.lg,
      child: Row(
        children: [
          Expanded(
            child: _SettingTitle(
              title: 'Set count',
              description: 'Choose how many sets to perform.',
            ),
          ),
          _NumberStepper(
            value: value,
            min: 1,
            max: 10,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _RepsCard extends StatelessWidget {
  const _RepsCard({
    required this.setCount,
    required this.perSetMode,
    required this.repsPerSet,
    required this.onModeChanged,
    required this.onAllRepsChanged,
    required this.onSetRepsChanged,
  });

  final int setCount;
  final bool perSetMode;
  final List<int> repsPerSet;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<int> onAllRepsChanged;
  final void Function(int index, int value) onSetRepsChanged;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: _SettingTitle(
                  title: 'Target reps',
                  description: 'Use the same reps or customize each set.',
                ),
              ),
              ImoChip(
                label: perSetMode ? 'Per set' : 'Same',
                variant: perSetMode
                    ? ImoChipVariant.selected
                    : ImoChipVariant.defaultChip,
                icon: const Icon(Icons.settings_rounded, size: 14),
                onTap: () => onModeChanged(!perSetMode),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (!perSetMode)
            Row(
              children: [
                Text('Every set', style: AppTextStyles.label),
                const Spacer(),
                _NumberStepper(
                  value: repsPerSet.first,
                  min: 1,
                  max: 50,
                  onChanged: onAllRepsChanged,
                ),
              ],
            )
          else
            Column(
              children: [
                for (var index = 0; index < setCount; index++) ...[
                  _PerSetRepsRow(
                    index: index,
                    value: repsPerSet[index],
                    onChanged: (value) => onSetRepsChanged(index, value),
                  ),
                  if (index != setCount - 1)
                    const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _PerSetRepsRow extends StatelessWidget {
  const _PerSetRepsRow({
    required this.index,
    required this.value,
    required this.onChanged,
  });

  final int index;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      variant: ImoCardVariant.subtle,
      paddingSize: ImoCardPadding.sm,
      child: Row(
        children: [
          Text('Set ${index + 1}', style: AppTextStyles.label),
          const Spacer(),
          _NumberStepper(
            value: value,
            min: 1,
            max: 50,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _RestTimeCard extends StatelessWidget {
  const _RestTimeCard({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      paddingSize: ImoCardPadding.lg,
      child: Row(
        children: [
          const Expanded(
            child: _SettingTitle(
              title: 'Rest time',
              description: 'Set the rest time between sets.',
            ),
          ),
          _NumberStepper(
            value: value,
            min: 30,
            max: 300,
            step: 15,
            suffix: 's',
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _PlanTotalCard extends StatelessWidget {
  const _PlanTotalCard({
    required this.setCount,
    required this.totalReps,
    required this.restSeconds,
    required this.estimatedMinutes,
  });

  final int setCount;
  final int totalReps;
  final int restSeconds;
  final int estimatedMinutes;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      variant: ImoCardVariant.subtle,
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Plan summary', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.md),
          _SummaryLine(label: 'Sets', value: '$setCount'),
          const SizedBox(height: AppSpacing.xs),
          _SummaryLine(label: 'Target reps', value: '$totalReps'),
          const SizedBox(height: AppSpacing.xs),
          _SummaryLine(label: 'Rest', value: '${restSeconds}s'),
          const SizedBox(height: AppSpacing.xs),
          _SummaryLine(label: 'Estimated time', value: '$estimatedMinutes min'),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: AppTextStyles.bodySmall),
        const Spacer(),
        Text(
          value,
          style: AppTextStyles.label,
        ),
      ],
    );
  }
}

class _SettingTitle extends StatelessWidget {
  const _SettingTitle({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.xxs),
        Text(description, style: AppTextStyles.bodySmall),
      ],
    );
  }
}

class _NumberStepper extends StatelessWidget {
  const _NumberStepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
    this.suffix = '',
  });

  final int value;
  final int min;
  final int max;
  final int step;
  final String suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(
          icon: Icons.remove_rounded,
          enabled: value > min,
          onTap: () => onChanged((value - step).clamp(min, max)),
        ),
        SizedBox(
          width: suffix.isEmpty ? 48 : 64,
          child: Text(
            '$value$suffix',
            textAlign: TextAlign.center,
            style: AppTextStyles.label.copyWith(fontSize: 16),
          ),
        ),
        _StepperButton(
          icon: Icons.add_rounded,
          enabled: value < max,
          filled: true,
          onTap: () => onChanged((value + step).clamp(min, max)),
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final bool enabled;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppColors.primary : AppColors.cardSubtle,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              icon,
              size: 18,
              color: filled ? AppColors.card : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

const _exerciseNames = {
  'pushup': 'Push-up',
  'lateral_raise': 'Lateral raise',
  'bicep_curl': 'Bicep curl',
};
