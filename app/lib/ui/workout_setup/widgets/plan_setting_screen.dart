import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';

class PlanSettingScreen extends StatefulWidget {
  const PlanSettingScreen({super.key, this.exerciseId = 'pushup'});

  final String exerciseId;

  @override
  State<PlanSettingScreen> createState() => _PlanSettingScreenState();
}

class _PlanSettingScreenState extends State<PlanSettingScreen> {
  int _setCount = 3;
  int _reps = 10;
  int _restSeconds = 60;

  String get _exerciseTitle =>
      _exerciseNames[widget.exerciseId] ?? _exerciseNames['pushup']!;

  int get _totalReps => _setCount * _reps;

  int get _estimatedMinutes =>
      ((_totalReps * 3 + _restSeconds * (_setCount - 1)) / 60).ceil();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _exerciseTitle,
      subtitle: '운동 계획 설정',
      showBackButton: true,
      scrollable: true,
      bottom: ImoButton(
        label: '다음',
        onPressed: () =>
            context.go('/sensor-guide?exercise=${widget.exerciseId}'),
      ),
      body: Column(
        children: [
          _SettingCard(
            title: '세트 수',
            description: '최대 10세트',
            value: _setCount,
            suffix: '',
            onDecrease: () =>
                setState(() => _setCount = (_setCount - 1).clamp(1, 10)),
            onIncrease: () =>
                setState(() => _setCount = (_setCount + 1).clamp(1, 10)),
          ),
          const SizedBox(height: AppSpacing.md),
          _SettingCard(
            title: '세트당 목표 횟수',
            description: '모든 세트 동일',
            value: _reps,
            suffix: '',
            chipLabel: '세트별',
            onDecrease: () => setState(() => _reps = (_reps - 1).clamp(1, 50)),
            onIncrease: () => setState(() => _reps = (_reps + 1).clamp(1, 50)),
          ),
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
  });

  final String title;
  final String description;
  final int value;
  final String suffix;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final String? chipLabel;

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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AppTextStyles.bodyLg.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                    if (chipLabel != null)
                      ImoChip(
                        label: chipLabel!,
                        variant: ImoChipVariant.defaultChip,
                        icon: const Icon(Icons.tune_rounded, size: 14),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(description, style: AppTextStyles.body),
              ],
            ),
          ),
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
                    TextSpan(text: ' $suffix', style: AppTextStyles.bodySmall),
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
      ),
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

const _exerciseNames = {
  'pushup': '푸시업',
  'lateral_raise': '싸레레',
  'bicep_curl': '이두컬',
};
