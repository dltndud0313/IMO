import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/dependencies.dart';
import '../../../data/repositories/device_connection_repository.dart';
import '../../../data/repositories/workout_repository.dart';
import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';
import '../view_model/workout_viewmodel.dart';

enum _WorkoutState { running, paused, resting }

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  Timer? _timer;
  late final WorkoutViewModel _workoutViewModel;
  _WorkoutState _state = _WorkoutState.running;
  bool _piConnected = false;
  bool _esp32Connected = false;
  bool _glassConnected = false;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    final repo = getIt<WorkoutRepository>();
    _workoutViewModel = WorkoutViewModel(
      repo,
      getIt<DeviceConnectionRepository>(),
    );
    _workoutViewModel.startListening(
      onConnectionStatus: (status) {
        if (mounted) {
          setState(() {
            _piConnected = status.piConnected;
            _esp32Connected = status.esp32Connected;
            _glassConnected = status.glassConnected;
          });
        }
      },
      onPaused: () {
        if (mounted) {
          setState(() => _state = _WorkoutState.paused);
        }
      },
      onResumed: () {
        if (mounted) {
          setState(() => _state = _WorkoutState.running);
        }
      },
    );
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _workoutViewModel.dispose();
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
    try {
      if (_state == _WorkoutState.paused) {
        _workoutViewModel.resumeWorkout();
      } else {
        _workoutViewModel.pauseWorkout();
      }
    } catch (_) {}
    setState(() {
      _state =
          _state == _WorkoutState.paused ? _WorkoutState.running : _WorkoutState.paused;
    });
  }

  Future<void> _finishWorkout() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ImoConfirmDialog(
        message: '운동을 정지하시겠습니까?',
        confirmLabel: '정지',
        cancelLabel: '계속',
        danger: true,
        onConfirm: () {
          try {
            _workoutViewModel.stopWorkout();
          } catch (_) {}
          Navigator.of(dialogContext).pop();
          context.go('/session-result?status=stopped');
        },
      ),
    );
  }

  void _emergencyStop() {
    try {
      _workoutViewModel.emergencyStop();
    } catch (_) {}
    context.go('/session-result?status=emergency_stopped');
  }

  String get _timeLabel {
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get _stateLabel {
    switch (_state) {
      case _WorkoutState.running:
        return '운동 중';
      case _WorkoutState.paused:
        return '일시정지';
      case _WorkoutState.resting:
        return '휴식 중';
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
      title: '푸시업',
      subtitle: _stateLabel,
      scrollable: true,
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: ImoButton(
                  label: _state == _WorkoutState.paused ? '재개' : '일시정지',
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
                  label: '종료',
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
            label: const Text('비상 종료'),
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
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          _ConnectionStatusCard(
            piConnected: _piConnected,
            esp32Connected: _esp32Connected,
            glassConnected: _glassConnected,
          ),
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
  });

  final String timeLabel;
  final String stateLabel;
  final StatusVariant stateVariant;

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
                    '스마트 글래스 안내 활성화',
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
                '운동 시간',
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
                'Pi가 운동 진행과 반복 수를 처리합니다.',
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

class _ConnectionStatusCard extends StatelessWidget {
  const _ConnectionStatusCard({
    required this.piConnected,
    required this.esp32Connected,
    required this.glassConnected,
  });

  final bool piConnected;
  final bool esp32Connected;
  final bool glassConnected;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      variant: ImoCardVariant.subtle,
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('기기 상태', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              StatusBadge(label: piConnected ? 'Pi connected' : 'Pi waiting', variant: piConnected ? StatusVariant.success : StatusVariant.warning),
              StatusBadge(label: esp32Connected ? 'ESP32 connected' : 'ESP32 waiting', variant: esp32Connected ? StatusVariant.success : StatusVariant.warning),
              StatusBadge(label: glassConnected ? 'Glass ready' : 'Glass waiting', variant: glassConnected ? StatusVariant.info : StatusVariant.warning),
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
        '현재 화면은 운동 중 UI 스켈레톤입니다. 이후 Pi WebSocket 이벤트로 세트 진행, 일시정지, 재개, 종료, 결과 화면 전환이 연결됩니다.',
        style: AppTextStyles.bodySmall,
      ),
    );
  }
}
