import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';

enum _WorkoutState { running, paused, resting }

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  Timer? _timer;
  _WorkoutState _state = _WorkoutState.running;
  int _elapsedSeconds = 0;
  final int _currentSet = 1;
  int _currentRep = 0;

  final int _setCount = 3;
  final List<int> _targetRepsPerSet = const [10, 10, 10];

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _state == _WorkoutState.paused) {
        return;
      }
      setState(() => _elapsedSeconds++);
    });
  }

  void _togglePause() {
    setState(() {
      _state =
          _state == _WorkoutState.paused ? _WorkoutState.running : _WorkoutState.paused;
    });
  }

  void _finishWorkout() {
    context.go('/session-result');
  }

  void _emergencyStop() {
    context.go('/home');
  }

  String get _timeLabel {
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get _stateLabel {
    switch (_state) {
      case _WorkoutState.running:
        return 'Running';
      case _WorkoutState.paused:
        return 'Paused';
      case _WorkoutState.resting:
        return 'Resting';
    }
  }

  StatusVariant get _stateVariant {
    switch (_state) {
      case _WorkoutState.running:
        return StatusVariant.success;
      case _WorkoutState.paused:
        return StatusVariant.warning;
      case _WorkoutState.resting:
        return StatusVariant.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Push-up',
      subtitle: _stateLabel,
      scrollable: true,
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: ImoButton(
                  label: _state == _WorkoutState.paused ? 'Resume' : 'Pause',
                  variant: ImoButtonVariant.outline,
                  leftIcon: Icon(
                    _state == _WorkoutState.paused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                  ),
                  onPressed: _togglePause,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ImoButton(
                  label: 'Stop',
                  variant: ImoButtonVariant.danger,
                  leftIcon: const Icon(Icons.stop_rounded),
                  onPressed: _finishWorkout,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton.icon(
            onPressed: _emergencyStop,
            icon: const Icon(Icons.emergency_rounded, size: 16),
            label: const Text('Emergency stop'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              textStyle: AppTextStyles.caption,
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WorkoutHeroCard(
            timeLabel: _timeLabel,
            stateLabel: _stateLabel,
            stateVariant: _stateVariant,
            currentSet: _currentSet,
            setCount: _setCount,
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          _CurrentRepCard(
            currentRep: _currentRep,
            targetRep: _targetRepsPerSet[_currentSet - 1],
            onIncrement: () {
              setState(() {
                final target = _targetRepsPerSet[_currentSet - 1];
                if (_currentRep < target) {
                  _currentRep++;
                }
              });
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _SetProgressCard(
            currentSet: _currentSet,
            currentRep: _currentRep,
            targets: _targetRepsPerSet,
          ),
          const SizedBox(height: AppSpacing.md),
          const _ConnectionStatusCard(),
          const SizedBox(height: AppSpacing.md),
          const _WorkoutNoticeCard(),
        ],
      ),
    );
  }
}

class _WorkoutHeroCard extends StatelessWidget {
  const _WorkoutHeroCard({
    required this.timeLabel,
    required this.stateLabel,
    required this.stateVariant,
    required this.currentSet,
    required this.setCount,
  });

  final String timeLabel;
  final String stateLabel;
  final StatusVariant stateVariant;
  final int currentSet;
  final int setCount;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      variant: ImoCardVariant.hero,
      paddingSize: ImoCardPadding.lg,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.primaryStrong],
          ),
          borderRadius: BorderRadius.circular(AppSpacing.heroCardRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.largeCardPadding),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.view_in_ar_rounded,
                    color: AppColors.card,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Glass cue active',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.card.withValues(alpha: 0.88),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  StatusBadge(
                    label: stateLabel,
                    variant: stateVariant,
                    showDot: false,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'Elapsed time',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.card.withValues(alpha: 0.78),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                timeLabel,
                style: AppTextStyles.metric.copyWith(
                  color: AppColors.card,
                  fontSize: 56,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Set $currentSet / $setCount',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.card.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentRepCard extends StatelessWidget {
  const _CurrentRepCard({
    required this.currentRep,
    required this.targetRep,
    required this.onIncrement,
  });

  final int currentRep;
  final int targetRep;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final progress = targetRep == 0 ? 0.0 : currentRep / targetRep;

    return ImoCard(
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Current set', style: AppTextStyles.label),
              const Spacer(),
              StatusBadge(
                label: '$currentRep / $targetRep reps',
                variant: StatusVariant.info,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 10,
              color: AppColors.primary,
              backgroundColor: AppColors.cardSubtle,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ImoButton(
            label: 'Simulate rep',
            size: ImoButtonSize.md,
            variant: ImoButtonVariant.secondary,
            leftIcon: const Icon(Icons.add_rounded),
            onPressed: currentRep >= targetRep ? null : onIncrement,
          ),
        ],
      ),
    );
  }
}

class _SetProgressCard extends StatelessWidget {
  const _SetProgressCard({
    required this.currentSet,
    required this.currentRep,
    required this.targets,
  });

  final int currentSet;
  final int currentRep;
  final List<int> targets;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Workout plan', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.md),
          for (var index = 0; index < targets.length; index++) ...[
            _SetProgressRow(
              index: index + 1,
              target: targets[index],
              currentRep: index + 1 == currentSet ? currentRep : 0,
              active: index + 1 == currentSet,
              done: index + 1 < currentSet,
            ),
            if (index != targets.length - 1) const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _SetProgressRow extends StatelessWidget {
  const _SetProgressRow({
    required this.index,
    required this.target,
    required this.currentRep,
    required this.active,
    required this.done,
  });

  final int index;
  final int target;
  final int currentRep;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final color = done
        ? AppColors.success
        : active
            ? AppColors.primary
            : AppColors.textTertiary;

    return ImoCard(
      variant: active || done ? ImoCardVariant.subtle : ImoCardVariant.outlined,
      paddingSize: ImoCardPadding.sm,
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: active || done ? 1 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: AppTextStyles.caption.copyWith(
                color: active || done ? AppColors.card : color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('Set $index', style: AppTextStyles.label),
          ),
          Text(
            active ? '$currentRep / $target' : '$target reps',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ConnectionStatusCard extends StatelessWidget {
  const _ConnectionStatusCard();

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      variant: ImoCardVariant.subtle,
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Device status', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.md),
          const Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              StatusBadge(label: 'Pi connected', variant: StatusVariant.success),
              StatusBadge(label: 'ESP32 connected', variant: StatusVariant.success),
              StatusBadge(label: 'Glass ready', variant: StatusVariant.info),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkoutNoticeCard extends StatelessWidget {
  const _WorkoutNoticeCard();

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      variant: ImoCardVariant.outlined,
      paddingSize: ImoCardPadding.lg,
      child: Text(
        'This screen is a UI skeleton. Pi WebSocket events will later drive set progress, pause/resume, stop, emergency, and session result transitions.',
        style: AppTextStyles.bodySmall,
      ),
    );
  }
}
