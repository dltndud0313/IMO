import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../mock/mock_data.dart';
import '../../models/exercise.dart';
import '../../models/routine.dart';
import '../../models/session_record.dart';
import '../../db/database_helper.dart';
import '../../providers/realtime_provider.dart';
import '../../services/achievement_service.dart';
import '../../services/settings_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/nav.dart';
import '../../widgets/achievement_unlock_dialog.dart';
import '../../widgets/confetti_overlay.dart';
import '../../widgets/emg_waveform.dart';
import '../../widgets/rest_timer.dart';

/// 루틴을 순서대로 실행하는 화면.
/// 운동 → 휴식 → 운동 → 휴식 → ... → 완료
class RoutineSessionScreen extends ConsumerStatefulWidget {
  final Routine routine;
  const RoutineSessionScreen({super.key, required this.routine});

  @override
  ConsumerState<RoutineSessionScreen> createState() =>
      _RoutineSessionScreenState();
}

enum _Phase { ready, exercising, resting, done }

class _RoutineSessionScreenState
    extends ConsumerState<RoutineSessionScreen>
    with SingleTickerProviderStateMixin {
  int _currentItemIndex = 0;
  int _currentSet = 1;
  _Phase _phase = _Phase.ready;
  int _prevRepCount = 0;

  // rep bounce 애니메이션
  late final AnimationController _bounceCtrl;
  late final Animation<double> _bounceAnim;

  // 세션 결과 집계용
  final List<_SetResult> _setResults = [];
  DateTime? _sessionStart;

  RoutineItem get _currentItem => widget.routine.items[_currentItemIndex];
  bool get _isLastItem =>
      _currentItemIndex >= widget.routine.items.length - 1;
  bool get _isLastSet => _currentSet >= _currentItem.sets;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bounceAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 0.95), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  Exercise? _findExercise(String id) {
    final all = MockData.workoutExercises;
    final match = all.where((e) => e.id == id);
    return match.isNotEmpty ? match.first : null;
  }

  void _onRepUpdate(int repCount) {
    if (repCount > _prevRepCount && _prevRepCount > 0) {
      _bounceCtrl.forward(from: 0);
      if (SettingsService().hapticEnabled) {
        HapticFeedback.lightImpact();
      }
    }
    _prevRepCount = repCount;
  }

  void _startExercise() {
    _sessionStart ??= DateTime.now();
    ref.read(realtimeProvider.notifier).start();
    setState(() => _phase = _Phase.exercising);
  }

  void _finishSet() {
    final state = ref.read(realtimeProvider);
    ref.read(realtimeProvider.notifier).stop();

    _setResults.add(_SetResult(
      exerciseId: _currentItem.exerciseId,
      reps: state.repCount,
      compensationCount: state.isCompensation ? 1 : 0,
      ch1: state.ch1,
      ch2: state.ch2,
      ch3: state.ch3,
    ));

    if (_isLastSet && _isLastItem) {
      // 루틴 전체 완료
      setState(() => _phase = _Phase.done);
      _saveResults();
    } else if (_isLastSet) {
      // 다음 운동으로
      setState(() {
        _phase = _Phase.resting;
      });
    } else {
      // 같은 운동 다음 세트 → 휴식
      setState(() {
        _phase = _Phase.resting;
      });
    }
  }

  void _onRestComplete() {
    if (_isLastSet) {
      // 다음 운동
      setState(() {
        _currentItemIndex++;
        _currentSet = 1;
        _phase = _Phase.ready;
      });
    } else {
      // 다음 세트
      setState(() {
        _currentSet++;
        _phase = _Phase.ready;
      });
    }
  }

  Future<void> _saveResults() async {
    if (_setResults.isEmpty) return;
    // 운동별로 그룹핑하여 저장
    final grouped = <String, List<_SetResult>>{};
    for (final r in _setResults) {
      grouped.putIfAbsent(r.exerciseId, () => []).add(r);
    }

    final db = DatabaseHelper();
    for (final entry in grouped.entries) {
      final sets = entry.value;
      final totalReps =
          sets.fold<int>(0, (sum, s) => sum + s.reps);
      final totalComp =
          sets.fold<int>(0, (sum, s) => sum + s.compensationCount);
      final avgCh1 =
          sets.map((s) => s.ch1).reduce((a, b) => a + b) / sets.length;
      final avgCh2 =
          sets.map((s) => s.ch2).reduce((a, b) => a + b) / sets.length;
      final avgCh3 =
          sets.map((s) => s.ch3).reduce((a, b) => a + b) / sets.length;

      final ex = _findExercise(entry.key);
      final record = SessionRecord(
        date: DateTime.now(),
        exerciseName: ex?.name ?? entry.key,
        totalReps: totalReps,
        compensationCount: totalComp,
        avgCh1: avgCh1,
        avgCh2: avgCh2,
        avgCh3: avgCh3,
        comment: '루틴 "${widget.routine.name}" — ${sets.length}세트 완료',
      );
      await db.insertSession(record);
    }
    final newly = await AchievementService().checkAfterSession();
    if (newly.isNotEmpty && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AchievementUnlockDialog.showAll(context, newly);
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (_phase == _Phase.done || _phase == _Phase.ready) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('중단하시겠어요?'),
        content: const Text('진행 중인 루틴이 중단됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('계속'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('중단',
                style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final exercise = _findExercise(_currentItem.exerciseId);
    final exerciseName = exercise?.name ?? _currentItem.exerciseId;

    return PopScope(
      canPop: _phase == _Phase.done || _phase == _Phase.ready,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.routine.name),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              if (await _onWillPop()) {
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _buildBody(exerciseName),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(String exerciseName) {
    switch (_phase) {
      case _Phase.ready:
        return _buildReady(exerciseName);
      case _Phase.exercising:
        return _buildExercising(exerciseName);
      case _Phase.resting:
        return _buildResting();
      case _Phase.done:
        return _buildDone();
    }
  }

  Widget _buildReady(String exerciseName) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 진행 표시
        Text(
          '${_currentItemIndex + 1} / ${widget.routine.items.length}',
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          exerciseName,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '세트 $_currentSet / ${_currentItem.sets}',
          style: const TextStyle(
            fontSize: 18,
            color: AppTheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '목표: ${_currentItem.targetReps}회',
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 48),
        ElevatedButton.icon(
          onPressed: _startExercise,
          icon: const Icon(Icons.play_arrow),
          label: const Text('시작'),
        ),
      ],
    );
  }

  Widget _buildExercising(String exerciseName) {
    final state = ref.watch(realtimeProvider);
    final notifier = ref.read(realtimeProvider.notifier);
    _onRepUpdate(state.repCount);
    final progress = (state.repCount / _currentItem.targetReps)
        .clamp(0.0, 1.0);
    return Column(
      children: [
        // 상단 정보
        Text(
          exerciseName,
          style: const TextStyle(
            fontSize: 18,
            color: AppTheme.textSecondary,
          ),
        ),
        Text(
          '세트 $_currentSet / ${_currentItem.sets}',
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        // 반복 수 / 목표
        ScaleTransition(
          scale: _bounceAnim,
          child: Text(
            '${state.repCount} / ${_currentItem.targetReps}',
            style: const TextStyle(
              fontSize: 84,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
              height: 1,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 진행 바
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: AppTheme.border,
            valueColor:
                const AlwaysStoppedAnimation(AppTheme.primary),
          ),
        ),
        const SizedBox(height: 16),
        // EMG 파형
        EmgWaveform(
          samples: notifier.ch1Wave,
          color: AppTheme.primary,
          label: '실시간 EMG',
          height: 70,
        ),
        const Spacer(),
        // EMG 채널
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ChVal(label: 'CH1', value: state.ch1),
                _ChVal(label: 'CH2', value: state.ch2),
                _ChVal(label: 'CH3', value: state.ch3),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  if (notifier.isPaused) {
                    notifier.resume();
                  } else {
                    notifier.pause();
                  }
                  setState(() {});
                },
                icon: Icon(
                    notifier.isPaused ? Icons.play_arrow : Icons.pause),
                label:
                    Text(notifier.isPaused ? '재개' : '일시정지'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                ),
                onPressed: _finishSet,
                icon: const Icon(Icons.stop),
                label: const Text('세트 종료'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildResting() {
    return Center(
      child: RestTimer(
        seconds: _currentItem.restSeconds,
        onComplete: _onRestComplete,
      ),
    );
  }

  Widget _buildDone() {
    final totalReps =
        _setResults.fold<int>(0, (sum, r) => sum + r.reps);
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle,
                  size: 80, color: AppTheme.success),
              const SizedBox(height: 16),
              const Text(
                '루틴 완료!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_setResults.length}세트 · 총 $totalReps회',
                style: const TextStyle(
                  fontSize: 18,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () => Nav.toHome(context),
                child: const Text('홈으로'),
              ),
            ],
          ),
        ),
        const Positioned.fill(child: ConfettiOverlay()),
      ],
    );
  }
}

class _ChVal extends StatelessWidget {
  final String label;
  final double value;
  const _ChVal({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        Text(value.toStringAsFixed(1),
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _SetResult {
  final String exerciseId;
  final int reps;
  final int compensationCount;
  final double ch1;
  final double ch2;
  final double ch3;
  const _SetResult({
    required this.exerciseId,
    required this.reps,
    required this.compensationCount,
    required this.ch1,
    required this.ch2,
    required this.ch3,
  });
}
