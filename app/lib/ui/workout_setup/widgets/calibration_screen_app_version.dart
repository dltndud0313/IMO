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

enum _CalibrationStage { ready, measuringRest, measuringMvc, wearGlasses, failed }

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
  String _statusMessage = '';
  late final WorkoutSetupViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = WorkoutSetupViewModel.withCalibration(
      getIt<CalibrationRepository>(),
      workoutRepository: getIt<WorkoutRepository>(),
    );
    _viewModel.listenCalibrationStatus(
      onStage: (stage) {
        switch (stage) {
          case CalibrationStage.measuringRest:
            _setStage(_CalibrationStage.measuringRest);
          case CalibrationStage.measuringMvc:
            _setStage(_CalibrationStage.measuringMvc);
          case CalibrationStage.success:
            _setStage(_CalibrationStage.wearGlasses);
          case CalibrationStage.failed:
            _setStage(_CalibrationStage.failed);
        }
      },
      onStatus: (status) {
        if (!mounted) {
          return;
        }
        setState(() => _statusMessage = status.message);
      },
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
    // Pi가 첫 calibration_status(started)를 보내기 전까지의 낙관적 단계.
    setState(() {
      _statusMessage = '';
      _stage = _CalibrationStage.measuringRest;
    });
  }

  bool get _isMeasuring =>
      _stage == _CalibrationStage.measuringRest ||
      _stage == _CalibrationStage.measuringMvc;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '캘리브레이션',
      showBackButton: !_isMeasuring,
      onBack: () => context.go('/sensor-guide?exercise=${widget.exerciseId}'),
      scrollable: true,
      bottom: AppRuntimeFlags.uiPreviewMode
          ? _buildPreviewBottom(context)
          : _buildBottom(context),
      body: Column(
        children: [
          _CalibrationStatusCard(
            stage: _stage,
            statusMessage: _statusMessage,
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          if (_stage == _CalibrationStage.failed)
            _CalibrationRetryGuide(statusMessage: _statusMessage)
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
      case _CalibrationStage.measuringRest:
        return const ImoButton(
          label: '안정 자세 측정 중...',
          loading: true,
          disabled: true,
        );
      case _CalibrationStage.measuringMvc:
        return const ImoButton(
          label: '최대 힘 측정 중...',
          loading: true,
          disabled: true,
        );
      case _CalibrationStage.wearGlasses:
        return ImoButton(
          label: '운동 시작',
          onPressed: () async {
            await _viewModel.startWorkout();
            if (!context.mounted) return;
            context.go('/workout');
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
  const _CalibrationStatusCard({
    required this.stage,
    this.statusMessage,
  });

  final _CalibrationStage stage;
  final String? statusMessage;

  @override
  Widget build(BuildContext context) {
    final palette = _CalibrationPalette.fromStage(stage);
    final description = statusMessage != null && statusMessage!.trim().isNotEmpty
        ? statusMessage!.trim()
        : palette.description;

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
            description,
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
  const _CalibrationRetryGuide({
    this.statusMessage,
  });

  final String? statusMessage;

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
          if (statusMessage != null && statusMessage!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              statusMessage!.trim(),
              style: AppTextStyles.body.copyWith(color: AppColors.warning),
            ),
          ],
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
      case _CalibrationStage.measuringRest:
        return const _CalibrationPalette(
          title: '힘을 빼주세요',
          description: '지금은 몸에 힘을 완전히 빼고\n편하게 자세를 유지해 주세요.',
          icon: Icons.self_improvement_rounded,
          color: Color(0xFFA9CCF5),
        );
      case _CalibrationStage.measuringMvc:
        return const _CalibrationPalette(
          title: '최대한 힘을 주세요',
          description: '이제 측정하는 근육에 최대한 힘을 주고\n3초간 버텨 주세요!',
          icon: Icons.bolt_rounded,
          color: AppColors.primary,
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
