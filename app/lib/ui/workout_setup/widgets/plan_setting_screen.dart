import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/dependencies.dart';
import '../../../data/repositories/workout_repository.dart';
import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';
import '../view_model/workout_setup_viewmodel.dart';
import 'exercise_target_regions.dart' show exerciseDisplayName;

class PlanSettingScreen extends StatefulWidget {
  const PlanSettingScreen({super.key, this.exerciseId = 'pushup'});

  final String exerciseId;

  @override
  State<PlanSettingScreen> createState() => _PlanSettingScreenState();
}

class _PlanSettingScreenState extends State<PlanSettingScreen> {
  int _setCount = 3;
  List<int> _targetRepsPerSet = [12, 12, 10];
  int _restSeconds = 60;
  bool _submitting = false;
  bool _perSetMode = false;
  // 제출 단계별 안내 문구. 비어 있으면 표시하지 않음.
  String _submitMessage = '';
  Timer? _submitStageTimer;
  late final WorkoutSetupViewModel _viewModel;

  int get _totalReps => _targetRepsPerSet.fold(0, (sum, reps) => sum + reps);

  int get _estimatedMinutes =>
      ((_totalReps * 3 + _restSeconds * (_setCount - 1)) / 60).ceil();

  @override
  void initState() {
    super.initState();
    _viewModel = WorkoutSetupViewModel(getIt<WorkoutRepository>());
  }

  @override
  void dispose() {
    _submitStageTimer?.cancel();
    super.dispose();
  }

  void _syncSetCount(int nextCount) {
    setState(() {
      _setCount = nextCount;
      if (_targetRepsPerSet.length < nextCount) {
        _targetRepsPerSet = [
          ..._targetRepsPerSet,
          ...List<int>.filled(nextCount - _targetRepsPerSet.length, 10),
        ];
      } else {
        _targetRepsPerSet = _targetRepsPerSet.take(nextCount).toList();
      }
    });
  }

  void _changeAllReps(int delta) {
    setState(() {
      _targetRepsPerSet = [
        for (final reps in _targetRepsPerSet) (reps + delta).clamp(1, 50),
      ];
    });
  }

  void _setAllReps(int value) {
    final clamped = value.clamp(1, 50);
    setState(() {
      _targetRepsPerSet = List<int>.filled(_setCount, clamped);
    });
  }

  void _setSetReps(int index, int value) {
    final clamped = value.clamp(1, 50);
    setState(() {
      final nextReps = [..._targetRepsPerSet];
      nextReps[index] = clamped;
      _targetRepsPerSet = nextReps;
    });
  }

  void _changeSetReps(int index, int delta) {
    setState(() {
      final nextReps = [..._targetRepsPerSet];
      nextReps[index] = (nextReps[index] + delta).clamp(1, 50);
      _targetRepsPerSet = nextReps;
    });
  }

  void _togglePerSetMode() {
    setState(() {
      if (_perSetMode) {
        final reps = _targetRepsPerSet.first;
        _targetRepsPerSet = List<int>.filled(_setCount, reps);
      }
      _perSetMode = !_perSetMode;
    });
  }

  Future<void> _submitPlan() async {
    // 즉시 "보내는 중" 상태로 전환해 사용자가 버튼을 다시 누르지 않도록 한다.
    setState(() {
      _submitting = true;
      _submitMessage = 'Pi 에 운동 계획을 전송하고 있어요...';
    });
    // 2초 이상 걸리면 "응답 대기" 로 문구를 바꿔, 멈춘 게 아니라 Pi 가 처리 중임을 안내.
    _submitStageTimer?.cancel();
    _submitStageTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _submitMessage = 'Pi 응답을 기다리는 중이에요...');
      }
    });
    try {
      final result = await _viewModel.submitWorkoutPlan(
        exerciseType: widget.exerciseId,
        setCount: _setCount,
        targetRepsPerSet: _targetRepsPerSet,
        restSec: _restSeconds,
      );
      if (!result.accepted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.validationErrors.join(', '))),
          );
        }
        return;
      }
      if (mounted) {
        context.go('/sensor-guide?exercise=${widget.exerciseId}');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Pi connection failed.')));
      }
    } finally {
      _submitStageTimer?.cancel();
      if (mounted) {
        setState(() {
          _submitting = false;
          _submitMessage = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '운동 계획 설정',
      showBackButton: true,
      onBack: () => context.go('/workout-guide?exercise=${widget.exerciseId}'),
      scrollable: true,
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_submitting && _submitMessage.isNotEmpty) ...[
            _SubmitProgressBanner(message: _submitMessage),
            const SizedBox(height: AppSpacing.sm),
          ],
          ImoButton(
            label: _submitting ? '전송 중...' : '다음',
            loading: _submitting,
            disabled: _submitting,
            onPressed: _submitPlan,
          ),
        ],
      ),
      body: Column(
        children: [
          _ExerciseNameHeader(exerciseId: widget.exerciseId),
          const SizedBox(height: AppSpacing.md),
          _SettingCard(
            title: '세트 수',
            description: '최대 10세트',
            value: _setCount,
            suffix: '',
            min: 1,
            max: 10,
            inputTitle: '세트 수 입력',
            onDecrease: () => _syncSetCount((_setCount - 1).clamp(1, 10)),
            onIncrease: () => _syncSetCount((_setCount + 1).clamp(1, 10)),
            onValueChanged: _syncSetCount,
          ),
          const SizedBox(height: AppSpacing.md),
          _SettingCard(
            title: '세트당 목표 횟수',
            description: _perSetMode ? '세트별로 각각 설정' : '모든 세트 동일',
            value: _targetRepsPerSet.first,
            suffix: '',
            min: 1,
            max: 50,
            inputTitle: '목표 횟수 입력',
            chipLabel: _perSetMode ? '전체 동일' : '세트별',
            chipSelected: _perSetMode,
            onChipTap: _togglePerSetMode,
            onDecrease: () => _changeAllReps(-1),
            onIncrease: () => _changeAllReps(1),
            onValueChanged: _perSetMode ? null : _setAllReps,
            showCounter: !_perSetMode,
          ),
          if (_perSetMode) ...[
            const SizedBox(height: AppSpacing.sm),
            _PerSetRepsCard(
              repsPerSet: _targetRepsPerSet,
              onDecrease: (index) => _changeSetReps(index, -1),
              onIncrease: (index) => _changeSetReps(index, 1),
              onSet: _setSetReps,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _SettingCard(
            title: '세트 간 휴식',
            description: '30 ~ 300초',
            value: _restSeconds,
            suffix: '초',
            min: 30,
            max: 300,
            inputTitle: '휴식 시간 입력',
            onDecrease: () => setState(
              () => _restSeconds = (_restSeconds - 15).clamp(30, 300),
            ),
            onIncrease: () => setState(
              () => _restSeconds = (_restSeconds + 15).clamp(30, 300),
            ),
            onValueChanged: (v) =>
                setState(() => _restSeconds = v.clamp(30, 300)),
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

/// 운동 계획 전송 중 사용자에게 단계별 안내 문구를 보여주는 작은 배너.
///
/// Pi WebSocket ack 까지 대기하는 동안 화면이 멈춘 것처럼 보여서 추가.
class _SubmitProgressBanner extends StatelessWidget {
  const _SubmitProgressBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primaryStrong,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primaryStrong,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// 운동 계획 화면 최상단에 표시되는 "어떤 운동의 계획을 설정 중인지" 헤더.
class _ExerciseNameHeader extends StatelessWidget {
  const _ExerciseNameHeader({required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      variant: ImoCardVariant.subtle,
      paddingSize: ImoCardPadding.md,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              color: AppColors.primaryStrong,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              exerciseDisplayName(exerciseId),
              style: AppTextStyles.sectionTitle,
            ),
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
    this.chipSelected = false,
    this.onChipTap,
    this.showCounter = true,
    this.onValueChanged,
    this.min = 1,
    this.max = 999,
    this.inputTitle,
  });

  final String title;
  final String description;
  final int value;
  final String suffix;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final String? chipLabel;
  final bool chipSelected;
  final VoidCallback? onChipTap;
  final bool showCounter;
  /// 숫자 영역 탭 시 직접 입력 다이얼로그 결과 처리.
  /// null 이면 직접 입력 비활성.
  final ValueChanged<int>? onValueChanged;
  final int min;
  final int max;
  final String? inputTitle;

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
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyLg.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(description, style: AppTextStyles.body),
                if (chipLabel != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  ImoChip(
                    label: chipLabel!,
                    selected: chipSelected,
                    variant: ImoChipVariant.defaultChip,
                    icon: const Icon(Icons.tune_rounded, size: 14),
                    onTap: onChipTap,
                  ),
                ],
              ],
            ),
          ),
          if (showCounter) ...[
            const SizedBox(width: AppSpacing.sm),
            _RoundButton(
              icon: Icons.remove_rounded,
              color: AppColors.cardSubtle,
              iconColor: AppColors.textPrimary,
              onTap: onDecrease,
            ),
            InkWell(
              onTap: onValueChanged == null
                  ? null
                  : () async {
                      final result = await showNumberInputDialog(
                        context,
                        title: inputTitle ?? title,
                        initialValue: value,
                        min: min,
                        max: max,
                        suffix: suffix,
                      );
                      if (result != null) onValueChanged!(result);
                    },
              borderRadius: BorderRadius.circular(AppSpacing.sm),
              child: SizedBox(
                width: suffix.isEmpty ? 48 : 64,
                child: Text.rich(
                  TextSpan(
                    text: '$value',
                    children: [
                      if (suffix.isNotEmpty)
                        TextSpan(
                          text: ' $suffix',
                          style: AppTextStyles.bodySmall,
                        ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.sectionTitle,
                ),
              ),
            ),
            _RoundButton(
              icon: Icons.add_rounded,
              color: AppColors.primary,
              iconColor: AppColors.card,
              onTap: onIncrease,
            ),
          ],
        ],
      ),
    );
  }
}

/// 숫자 직접 입력 다이얼로그.
///
/// [min] ~ [max] 범위로 자동 clamp. 입력값이 숫자가 아니면 null 반환 (취소 동일).
Future<int?> showNumberInputDialog(
  BuildContext context, {
  required String title,
  required int initialValue,
  required int min,
  required int max,
  String suffix = '',
}) async {
  final controller = TextEditingController(text: '$initialValue');
  return showDialog<int>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(title, style: AppTextStyles.sectionTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: AppTextStyles.title,
              decoration: InputDecoration(
                hintText: '$min ~ $max',
                suffixText: suffix.isEmpty ? null : suffix,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$min ~ $max 범위로 입력해주세요',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed == null) {
                Navigator.of(ctx).pop();
                return;
              }
              Navigator.of(ctx).pop(parsed.clamp(min, max));
            },
            child: const Text('확인'),
          ),
        ],
      );
    },
  );
}

class _PerSetRepsCard extends StatelessWidget {
  const _PerSetRepsCard({
    required this.repsPerSet,
    required this.onDecrease,
    required this.onIncrease,
    required this.onSet,
  });

  final List<int> repsPerSet;
  final ValueChanged<int> onDecrease;
  final ValueChanged<int> onIncrease;
  /// (index, newValue) — 직접 입력 결과
  final void Function(int index, int newValue) onSet;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      variant: ImoCardVariant.outlined,
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('세트별 목표 횟수', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.md),
          for (var index = 0; index < repsPerSet.length; index++) ...[
            _PerSetRepsRow(
              index: index,
              reps: repsPerSet[index],
              onDecrease: () => onDecrease(index),
              onIncrease: () => onIncrease(index),
              onSet: (v) => onSet(index, v),
            ),
            if (index != repsPerSet.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _PerSetRepsRow extends StatelessWidget {
  const _PerSetRepsRow({
    required this.index,
    required this.reps,
    required this.onDecrease,
    required this.onIncrease,
    required this.onSet,
  });

  final int index;
  final int reps;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final ValueChanged<int> onSet;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text('${index + 1}세트', style: AppTextStyles.bodyLg)),
        _RoundButton(
          icon: Icons.remove_rounded,
          color: AppColors.cardSubtle,
          iconColor: AppColors.textPrimary,
          onTap: onDecrease,
        ),
        InkWell(
          onTap: () async {
            final result = await showNumberInputDialog(
              context,
              title: '${index + 1}세트 횟수 입력',
              initialValue: reps,
              min: 1,
              max: 50,
            );
            if (result != null) onSet(result);
          },
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          child: SizedBox(
            width: 52,
            child: Text(
              '$reps',
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionTitle,
            ),
          ),
        ),
        _RoundButton(
          icon: Icons.add_rounded,
          color: AppColors.primary,
          iconColor: AppColors.card,
          onTap: onIncrease,
        ),
      ],
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
