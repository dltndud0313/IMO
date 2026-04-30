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
    this.autoStart = false,
  });

  final String exerciseId;
  final bool autoStart;

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  _CalibrationStage _stage = _CalibrationStage.ready;

  String get _exerciseTitle =>
      _exerciseNames[widget.exerciseId] ?? _exerciseNames['pushup']!;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      _startCalibration();
    }
  }

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
      onBack: () => context.go('/sensor-guide?exercise=${widget.exerciseId}'),
      scrollable: true,
      bottom: _buildBottom(context),
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
          description: '자세를 잡고 글래스의 안내에 따라 측정을 시작하세요.',
          glassMessage: '측정 대기 중',
          badgeLabel: '대기',
          badgeVariant: StatusVariant.neutral,
          icon: Icons.play_arrow_rounded,
          color: AppColors.primary,
        );
      case _CalibrationStage.measuring:
        return const _CalibrationPalette(
          title: '기준값 측정 중',
          description: '글래스에서 자동으로 진행됩니다. 필요한 자세로 가만히 있어주세요.',
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

const _exerciseNames = {
  'pushup': '푸시업',
  'lateral_raise': '싸레레',
  'bicep_curl': '이두컬',
};
