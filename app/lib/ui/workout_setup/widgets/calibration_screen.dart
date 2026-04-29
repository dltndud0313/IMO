import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';

enum _CalibrationStage { ready, measuring, success, failed }

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({
    super.key,
    this.exerciseId = 'pushup',
  });

  final String exerciseId;

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  _CalibrationStage _stage = _CalibrationStage.ready;

  String get _exerciseTitle =>
      _exerciseNames[widget.exerciseId] ?? _exerciseNames['pushup']!;

  void _startCalibration() {
    setState(() => _stage = _CalibrationStage.measuring);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!mounted || _stage != _CalibrationStage.measuring) {
        return;
      }
      setState(() => _stage = _CalibrationStage.success);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _exerciseTitle,
      subtitle: '캘리브레이션',
      showBackButton: _stage != _CalibrationStage.measuring,
      scrollable: true,
      bottom: _buildBottom(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
        return ImoButton(
          label: '캘리브레이션 시작',
          rightIcon: const Icon(Icons.play_arrow_rounded),
          onPressed: _startCalibration,
        );
      case _CalibrationStage.measuring:
        return const ImoButton(
          label: '기준값 측정 중...',
          loading: true,
          disabled: true,
        );
      case _CalibrationStage.success:
        return ImoButton(
          label: '운동 시작',
          rightIcon: const Icon(Icons.arrow_forward_rounded),
          onPressed: () => context.go('/workout'),
        );
      case _CalibrationStage.failed:
        return ImoButton(
          label: '다시 측정',
          leftIcon: const Icon(Icons.refresh_rounded),
          onPressed: _startCalibration,
        );
    }
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
          const SizedBox(height: AppSpacing.md),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: palette.gradient,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: palette.gradient.last.withValues(alpha: 0.24),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Icon(palette.icon, color: AppColors.card, size: 38),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(palette.title, style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            palette.description,
            textAlign: TextAlign.center,
            style: AppTextStyles.body,
          ),
          const SizedBox(height: AppSpacing.md),
          StatusBadge(
            label: palette.badgeLabel,
            variant: palette.badgeVariant,
            size: StatusBadgeSize.md,
          ),
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
    final ready = stage == _CalibrationStage.success;
    final measuring = stage == _CalibrationStage.measuring;

    return ImoCard(
      paddingSize: ImoCardPadding.lg,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.cardSubtle,
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            ),
            child: const Icon(
              Icons.view_in_ar_rounded,
              color: AppColors.primaryStrong,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('스마트 글래스', style: AppTextStyles.label),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  measuring
                      ? '기준값 상태를 준비하고 있습니다.'
                      : ready
                          ? '운동 안내를 표시할 준비가 되었습니다.'
                          : '캘리브레이션을 기다리는 중입니다.',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          StatusBadge(
            label: ready
                ? '준비됨'
                : measuring
                    ? '동기화 중'
                    : '대기',
            variant: ready
                ? StatusVariant.success
                : measuring
                    ? StatusVariant.info
                    : StatusVariant.neutral,
          ),
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
    final measuring = stage == _CalibrationStage.measuring;
    final success = stage == _CalibrationStage.success;

    return ImoCard(
      variant: ImoCardVariant.outlined,
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('측정 중 확인', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.md),
          _ChecklistLine(
            text: '자세를 유지하고 센서가 떨어지지 않게 합니다.',
            done: measuring || success,
          ),
          const SizedBox(height: AppSpacing.xs),
          _ChecklistLine(
            text: 'Pi의 기준 동작 안내를 따릅니다.',
            done: success,
          ),
          const SizedBox(height: AppSpacing.xs),
          _ChecklistLine(
            text: '앱에 캘리브레이션 성공이 표시될 때까지 기다립니다.',
            done: success,
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
            '다시 시도하기 전',
            style: AppTextStyles.label.copyWith(color: AppColors.warning),
          ),
          const SizedBox(height: AppSpacing.md),
          const _RetryLine('모든 센서가 단단히 부착되었는지 확인합니다.'),
          const SizedBox(height: AppSpacing.xs),
          const _RetryLine('기준값 측정 중에는 불필요하게 움직이지 않습니다.'),
          const SizedBox(height: AppSpacing.xs),
          const _RetryLine('Pi 상태를 확인한 뒤 캘리브레이션을 다시 시작합니다.'),
        ],
      ),
    );
  }
}

class _ChecklistLine extends StatelessWidget {
  const _ChecklistLine({
    required this.text,
    required this.done,
  });

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
        Expanded(child: Text(text, style: AppTextStyles.bodySmall)),
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
        const Icon(
          Icons.warning_amber_rounded,
          size: 16,
          color: AppColors.warning,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: Text(text, style: AppTextStyles.bodySmall)),
      ],
    );
  }
}

class _CalibrationPalette {
  const _CalibrationPalette({
    required this.title,
    required this.description,
    required this.badgeLabel,
    required this.badgeVariant,
    required this.icon,
    required this.gradient,
  });

  factory _CalibrationPalette.fromStage(_CalibrationStage stage) {
    switch (stage) {
      case _CalibrationStage.ready:
        return const _CalibrationPalette(
          title: '캘리브레이션 준비',
          description: '운동 전에 기준값 측정을 시작합니다.',
          badgeLabel: '준비',
          badgeVariant: StatusVariant.neutral,
          icon: Icons.play_arrow_rounded,
          gradient: [AppColors.primary, AppColors.primaryStrong],
        );
      case _CalibrationStage.measuring:
        return const _CalibrationPalette(
          title: '기준값 측정 중',
          description: 'Pi가 기준 데이터를 측정하는 동안 자세를 유지합니다.',
          badgeLabel: '측정 중',
          badgeVariant: StatusVariant.info,
          icon: Icons.autorenew_rounded,
          gradient: [AppColors.primary, AppColors.primaryStrong],
        );
      case _CalibrationStage.success:
        return const _CalibrationPalette(
          title: '캘리브레이션 완료',
          description: '기준값 준비가 끝났습니다. 운동을 시작할 수 있습니다.',
          badgeLabel: '성공',
          badgeVariant: StatusVariant.success,
          icon: Icons.check_rounded,
          gradient: [AppColors.secondary, Color(0xFF5DC447)],
        );
      case _CalibrationStage.failed:
        return const _CalibrationPalette(
          title: '캘리브레이션 실패',
          description: '센서 부착 상태를 확인하고 다시 시도해 주세요.',
          badgeLabel: '재시도',
          badgeVariant: StatusVariant.warning,
          icon: Icons.warning_amber_rounded,
          gradient: [Color(0xFFFFB371), AppColors.warning],
        );
    }
  }

  final String title;
  final String description;
  final String badgeLabel;
  final StatusVariant badgeVariant;
  final IconData icon;
  final List<Color> gradient;
}

const _exerciseNames = {
  'pushup': '푸시업',
  'lateral_raise': '사이드 레터럴 레이즈',
  'bicep_curl': '바이셉 컬',
};
