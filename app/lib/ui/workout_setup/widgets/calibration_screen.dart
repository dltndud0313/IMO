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
      subtitle: 'Calibration',
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
          label: 'Start calibration',
          rightIcon: const Icon(Icons.play_arrow_rounded),
          onPressed: _startCalibration,
        );
      case _CalibrationStage.measuring:
        return const ImoButton(
          label: 'Measuring baseline...',
          loading: true,
          disabled: true,
        );
      case _CalibrationStage.success:
        return ImoButton(
          label: 'Start workout',
          rightIcon: const Icon(Icons.arrow_forward_rounded),
          onPressed: () => context.go('/workout'),
        );
      case _CalibrationStage.failed:
        return ImoButton(
          label: 'Retry calibration',
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
                Text('Glass display', style: AppTextStyles.label),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  measuring
                      ? 'Baseline status is being prepared.'
                      : ready
                          ? 'Ready to show workout cues.'
                          : 'Waiting for calibration.',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          StatusBadge(
            label: ready
                ? 'Ready'
                : measuring
                    ? 'Syncing'
                    : 'Standby',
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
          Text('During calibration', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.md),
          _ChecklistLine(
            text: 'Stand still and keep the sensors attached.',
            done: measuring || success,
          ),
          const SizedBox(height: AppSpacing.xs),
          _ChecklistLine(
            text: 'Follow the baseline movement guide from Pi.',
            done: success,
          ),
          const SizedBox(height: AppSpacing.xs),
          _ChecklistLine(
            text: 'Wait until the app shows calibration success.',
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
            'Before retrying',
            style: AppTextStyles.label.copyWith(color: AppColors.warning),
          ),
          const SizedBox(height: AppSpacing.md),
          const _RetryLine('Check whether every sensor is attached firmly.'),
          const SizedBox(height: AppSpacing.xs),
          const _RetryLine('Avoid moving while the baseline is measured.'),
          const SizedBox(height: AppSpacing.xs),
          const _RetryLine('Restart calibration after checking Pi status.'),
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
          title: 'Ready to calibrate',
          description: 'Start baseline measurement before the workout.',
          badgeLabel: 'Ready',
          badgeVariant: StatusVariant.neutral,
          icon: Icons.play_arrow_rounded,
          gradient: [AppColors.primary, AppColors.primaryStrong],
        );
      case _CalibrationStage.measuring:
        return const _CalibrationPalette(
          title: 'Measuring baseline',
          description: 'Keep the posture stable while Pi measures baseline data.',
          badgeLabel: 'Measuring',
          badgeVariant: StatusVariant.info,
          icon: Icons.autorenew_rounded,
          gradient: [AppColors.primary, AppColors.primaryStrong],
        );
      case _CalibrationStage.success:
        return const _CalibrationPalette(
          title: 'Calibration complete',
          description: 'The baseline is ready. You can start the workout.',
          badgeLabel: 'Success',
          badgeVariant: StatusVariant.success,
          icon: Icons.check_rounded,
          gradient: [AppColors.secondary, Color(0xFF5DC447)],
        );
      case _CalibrationStage.failed:
        return const _CalibrationPalette(
          title: 'Calibration failed',
          description: 'Check sensor placement and try calibration again.',
          badgeLabel: 'Retry',
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
  'pushup': 'Push-up',
  'lateral_raise': 'Lateral raise',
  'bicep_curl': 'Bicep curl',
};
