import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_runtime_flags.dart';
import '../../../config/dependencies.dart';
import '../../../data/repositories/calibration_repository.dart';
import '../../../data/repositories/workout_repository.dart';
import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';
import '../view_model/workout_setup_viewmodel.dart';

enum _CalibrationStage { ready, measuring, success, failed }

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({
    super.key,
    this.exerciseId = 'pushup',
    this.autoStart = false,
  });

  final String exerciseId;
  final bool autoStart;

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  _CalibrationStage _stage = _CalibrationStage.ready;
  late final WorkoutSetupViewModel _viewModel;
  Timer? _calibrationTimeout;
  static const _calibrationTimeoutDuration = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    _viewModel = WorkoutSetupViewModel.withCalibration(
      getIt<CalibrationRepository>(),
      workoutRepository: getIt<WorkoutRepository>(),
    );
    _viewModel.listenCalibrationStatus(
      onStarted: () => _setStage(_CalibrationStage.measuring),
      onSuccess: _handleCalibrationSuccess,
      onFailed: () => _setStage(_CalibrationStage.failed),
    );
    if (widget.autoStart) {
      _startCalibration(sendToPi: false);
    }
  }

  @override
  void dispose() {
    _calibrationTimeout?.cancel();
    _viewModel.dispose();
    super.dispose();
  }

  void _setStage(_CalibrationStage stage) {
    if (!mounted) {
      return;
    }
    if (stage != _CalibrationStage.measuring) {
      _calibrationTimeout?.cancel();
    }
    setState(() => _stage = stage);
  }

  void _handleCalibrationSuccess() {
    if (!mounted) {
      return;
    }
    _calibrationTimeout?.cancel();
    setState(() => _stage = _CalibrationStage.success);
  }

  void _startCalibration({bool sendToPi = true}) {
    if (sendToPi) {
      unawaited(
        _viewModel.startCalibration(exerciseType: widget.exerciseId),
      );
    }
    _calibrationTimeout?.cancel();
    _calibrationTimeout = Timer(_calibrationTimeoutDuration, () {
      if (mounted && _stage == _CalibrationStage.measuring) {
        _setStage(_CalibrationStage.failed);
      }
    });
    setState(() => _stage = _CalibrationStage.measuring);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '캘리브레이션',
      showBackButton: _stage != _CalibrationStage.measuring,
      onBack: () => context.canPop()
          ? context.pop()
          : context.go('/sensor-guide?exercise=${widget.exerciseId}'),
      scrollable: true,
      bottom: AppRuntimeFlags.uiPreviewMode
          ? _buildPreviewBottom(context)
          : _buildBottom(context),
      body: Column(
        children: [
          _CalibrationStatusCard(stage: _stage),
          const SizedBox(height: AppSpacing.sectionGap),
          _GlassStatusCard(stage: _stage),
          const SizedBox(height: AppSpacing.md),
          if (_stage == _CalibrationStage.failed)
            const _CalibrationRetryGuide()
          else
            _CalibrationChecklist(stage: _stage),
        ],
      ),
    );
  }

  Widget _buildBottom(BuildContext context) {
    switch (_stage) {
      case _CalibrationStage.ready:
        return ImoButton(label: '캘리브레이션 시작', onPressed: _startCalibration);
      case _CalibrationStage.measuring:
        return const ImoButton(
          label: '글래스에서 측정 중...',
          loading: true,
          disabled: true,
        );
      case _CalibrationStage.success:
        return ImoButton(
          label: '운동 시작',
          onPressed: () async {
            try {
              await _viewModel.startWorkout();
              if (!context.mounted) {
                return;
              }
              context.go('/workout');
            } catch (_) {
              if (!context.mounted) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('운동 시작 요청에 실패했습니다. 다시 시도해주세요.')),
              );
            }
          },
        );
      case _CalibrationStage.failed:
        return ImoButton(
          label: '다시 시도',
          leftIcon: const Icon(Icons.refresh_rounded),
          onPressed: _startCalibration,
        );
    }
  }

  Widget _buildPreviewBottom(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildBottom(context),
        const SizedBox(height: AppSpacing.xs),
        TextButton(
          onPressed: () => context.go('/workout'),
          child: const Text('UI preview: go to workout'),
        ),
      ],
    );
  }
}

class _CalibrationStatusCard extends StatelessWidget {
  const _CalibrationStatusCard({required this.stage});

  final _CalibrationStage stage;

  @override
  Widget build(BuildContext context) {
    final palette = _CalibrationPalette.fromStage(stage);

    return ImoCard(
      variant: ImoCardVariant.hero,
      paddingSize: ImoCardPadding.lg,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: palette.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: palette.color.withValues(alpha: 0.22),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Icon(palette.icon, color: AppColors.card, size: 46),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            palette.title,
            textAlign: TextAlign.center,
            style: AppTextStyles.title.copyWith(fontSize: 24),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            palette.description,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyLg,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _GlassStatusCard extends StatelessWidget {
  const _GlassStatusCard({required this.stage});

  final _CalibrationStage stage;

  @override
  Widget build(BuildContext context) {
    final palette = _CalibrationPalette.fromStage(stage);

    return ImoCard(
      paddingSize: ImoCardPadding.lg,
      variant: stage == _CalibrationStage.success
          ? ImoCardVariant.subtle
          : ImoCardVariant.defaultCard,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: AppColors.cardSubtle,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.visibility_rounded,
              color: AppColors.primaryStrong,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('스마트글래스', style: AppTextStyles.sectionTitle),
                const SizedBox(height: AppSpacing.xxs),
                Text(palette.glassMessage, style: AppTextStyles.body),
              ],
            ),
          ),
          StatusBadge(label: palette.badgeLabel, variant: palette.badgeVariant),
        ],
      ),
    );
  }
}

class _CalibrationChecklist extends StatelessWidget {
  const _CalibrationChecklist({required this.stage});

  final _CalibrationStage stage;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      variant: ImoCardVariant.outlined,
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('점검 사항', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.md),
          _ChecklistLine(
            text: '센서가 피부에 잘 밀착되었는지 확인',
            done: stage != _CalibrationStage.ready,
          ),
          const SizedBox(height: AppSpacing.xs),
          _ChecklistLine(
            text: '측정 중 움직이지 않았는지 확인',
            done: stage == _CalibrationStage.success,
          ),
          const SizedBox(height: AppSpacing.xs),
          _ChecklistLine(
            text: '글래스와 연결 상태 확인',
            done: stage == _CalibrationStage.success,
          ),
        ],
      ),
    );
  }
}

class _CalibrationRetryGuide extends StatelessWidget {
  const _CalibrationRetryGuide();

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      variant: ImoCardVariant.outlined,
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '다시 시도 전 확인해주세요',
            style: AppTextStyles.sectionTitle.copyWith(
              color: const Color(0xFFB97509),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const _RetryLine('센서가 떨어지거나 들뜨지 않았는지 확인'),
          const SizedBox(height: AppSpacing.xs),
          const _RetryLine('측정 중 팔이나 몸이 움직이지 않도록 유지'),
          const SizedBox(height: AppSpacing.xs),
          const _RetryLine('스마트글래스 연결 상태 확인'),
        ],
      ),
    );
  }
}

class _ChecklistLine extends StatelessWidget {
  const _ChecklistLine({required this.text, required this.done});

  final String text;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 18,
          color: done ? AppColors.success : AppColors.textTertiary,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: Text(text, style: AppTextStyles.body)),
      ],
    );
  }
}

class _RetryLine extends StatelessWidget {
  const _RetryLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 3),
          child: Icon(Icons.circle, size: 5, color: AppColors.warning),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: Text(text, style: AppTextStyles.body)),
      ],
    );
  }
}

class _CalibrationPalette {
  const _CalibrationPalette({
    required this.title,
    required this.description,
    required this.glassMessage,
    required this.badgeLabel,
    required this.badgeVariant,
    required this.icon,
    required this.color,
  });

  factory _CalibrationPalette.fromStage(_CalibrationStage stage) {
    switch (stage) {
      case _CalibrationStage.ready:
        return const _CalibrationPalette(
          title: '기준값 측정 준비',
          description: '측정하는 동안 팔에 힘을 빼고 편하게 있어 주세요.\n준비되면 측정을 시작하세요.',
          glassMessage: '측정 대기 중',
          badgeLabel: '대기',
          badgeVariant: StatusVariant.neutral,
          icon: Icons.play_arrow_rounded,
          color: AppColors.primary,
        );
      case _CalibrationStage.measuring:
        return const _CalibrationPalette(
          title: '기준값 측정 중',
          description: '팔에 힘을 빼고 움직이지 말고 가만히 있어 주세요.',
          glassMessage: 'EMG 기준값 측정 중...',
          badgeLabel: '측정 중',
          badgeVariant: StatusVariant.info,
          icon: Icons.autorenew_rounded,
          color: Color(0xFFA9CCF5),
        );
      case _CalibrationStage.success:
        return const _CalibrationPalette(
          title: '측정 완료!',
          description: '이제 운동을 시작할 준비가 되었어요.',
          glassMessage: '동기화 완료, 운동 시작 대기',
          badgeLabel: '준비됨',
          badgeVariant: StatusVariant.success,
          icon: Icons.check_rounded,
          color: AppColors.secondary,
        );
      case _CalibrationStage.failed:
        return const _CalibrationPalette(
          title: '측정 실패',
          description: '기준값 측정 실패, 다시 시도해 주세요.',
          glassMessage: '재측정 필요',
          badgeLabel: '오류',
          badgeVariant: StatusVariant.warning,
          icon: Icons.warning_amber_rounded,
          color: AppColors.warning,
        );
    }
  }

  final String title;
  final String description;
  final String glassMessage;
  final String badgeLabel;
  final StatusVariant badgeVariant;
  final IconData icon;
  final Color color;
}
