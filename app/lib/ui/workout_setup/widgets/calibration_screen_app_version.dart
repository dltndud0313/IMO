import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_runtime_flags.dart';
import '../../../config/dependencies.dart';
import '../../../data/repositories/calibration_repository.dart';
import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';
import '../view_model/workout_setup_viewmodel.dart';

enum _CalibrationStage { ready, measuring, wearGlasses, failed }

class CalibrationScreenAppVersion extends StatefulWidget {
  const CalibrationScreenAppVersion({
    super.key,
    this.exerciseId = 'pushup',
    this.autoStart = false,
  });

  final String exerciseId;
  final bool autoStart;

  @override
  State<CalibrationScreenAppVersion> createState() =>
      _CalibrationScreenAppVersionState();
}

class _CalibrationScreenAppVersionState
    extends State<CalibrationScreenAppVersion> {
  _CalibrationStage _stage = _CalibrationStage.ready;
  late final WorkoutSetupViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = WorkoutSetupViewModel.withCalibration(
      getIt<CalibrationRepository>(),
    );
    _viewModel.listenCalibrationStatus(
      onStarted: () => _setStage(_CalibrationStage.measuring),
      onSuccess: () => _setStage(_CalibrationStage.wearGlasses),
      onFailed: () => _setStage(_CalibrationStage.failed),
    );
    if (widget.autoStart) {
      _startCalibration(sendToPi: false);
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _setStage(_CalibrationStage stage) {
    if (!mounted) {
      return;
    }
    setState(() => _stage = stage);
  }

  void _startCalibration({bool sendToPi = true}) {
    if (sendToPi) {
      unawaited(
        _viewModel.startCalibration(exerciseType: widget.exerciseId),
      );
    }
    setState(() => _stage = _CalibrationStage.measuring);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '캘리브레이션',
      showBackButton: _stage != _CalibrationStage.measuring,
      onBack: () => context.go('/sensor-guide?exercise=${widget.exerciseId}'),
      scrollable: true,
      bottom: AppRuntimeFlags.uiPreviewMode
          ? _buildPreviewBottom(context)
          : _buildBottom(context),
      body: Column(
        children: [
          _CalibrationStatusCard(stage: _stage),
          const SizedBox(height: AppSpacing.sectionGap),
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
          label: '기준값 측정 중...',
          loading: true,
          disabled: true,
        );
      case _CalibrationStage.wearGlasses:
        return ImoButton(
          label: '운동 시작',
          onPressed: () => context.go('/workout'),
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
            done: stage == _CalibrationStage.wearGlasses,
          ),
          const SizedBox(height: AppSpacing.xs),
          _ChecklistLine(
            text: '글래스와 연결 상태 확인',
            done: stage == _CalibrationStage.wearGlasses,
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
    required this.icon,
    required this.color,
  });

  factory _CalibrationPalette.fromStage(_CalibrationStage stage) {
    switch (stage) {
      case _CalibrationStage.ready:
        return const _CalibrationPalette(
          title: '기준값 측정 준비',
          description: '자세를 잡고 측정을 시작하세요.',
          icon: Icons.play_arrow_rounded,
          color: AppColors.primary,
        );
      case _CalibrationStage.measuring:
        return const _CalibrationPalette(
          title: '기준값 측정 중',
          description: '센서를 부착한 상태로 가만히 있어주세요.',
          icon: Icons.autorenew_rounded,
          color: Color(0xFFA9CCF5),
        );
      case _CalibrationStage.wearGlasses:
        return const _CalibrationPalette(
          title: '글래스를 착용해주세요',
          description: '측정이 완료되었어요. 스마트글래스를 착용한 뒤 운동을 시작해주세요.',
          icon: Icons.visibility_rounded,
          color: AppColors.secondary,
        );
      case _CalibrationStage.failed:
        return const _CalibrationPalette(
          title: '측정 실패',
          description: '기준값 측정 실패, 다시 시도해 주세요.',
          icon: Icons.warning_amber_rounded,
          color: AppColors.warning,
        );
    }
  }

  final String title;
  final String description;
  final IconData icon;
  final Color color;
}
