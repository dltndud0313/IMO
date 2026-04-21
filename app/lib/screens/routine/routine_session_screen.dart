import 'dart:async';

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
import '../../theme/app_tokens.dart';
import '../../utils/nav.dart';
import '../../widgets/achievement_unlock_dialog.dart';
import '../../widgets/confetti_overlay.dart';
import '../../widgets/emg_waveform.dart';
import '../../widgets/rest_timer.dart';
import '../../widgets/ui/gradient_button.dart';
import '../../widgets/ui/section_card.dart';

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

  // 경과 시간 표시용 1초 타이머
  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;

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
    _elapsedTimer?.cancel();
    super.dispose();
  }

  String get _elapsedLabel {
    final m = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _sessionStart == null) return;
      setState(() {
        _elapsed = DateTime.now().difference(_sessionStart!);
      });
    });
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
    _startElapsedTimer();
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
      child: _phase == _Phase.exercising
          ? Scaffold(body: _buildExercising(exerciseName))
          : Scaffold(
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

    return Column(
      children: [
        // ── 그라데이션 헤더 (close + 이름 + 세트 / 대형 rep 카운터)
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2A3470),
                Color(0xFF7B96E8),
                Color(0xFF72BFEE),
              ],
              stops: [0.0, 0.6, 1.0],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 20, 0),
                  child: Row(
                    children: [
                      _GlassIconButton(
                        icon: Icons.close,
                        onTap: () async {
                          if (await _onWillPop()) {
                            if (mounted) Navigator.pop(context);
                          }
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          exerciseName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '세트 $_currentSet / ${_currentItem.sets}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: ScaleTransition(
                    scale: _bounceAnim,
                    child: Column(
                      children: [
                        Text(
                          '${state.repCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 72,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -2,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '회 완료',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── 스크롤 영역
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.isCompensation) _buildCompensationBanner(),
                _buildEmgCard(notifier),
                const SizedBox(height: 12),
                _buildStatGrid(state),
              ],
            ),
          ),
        ),

        // ── 하단 고정 액션바
        _buildActionBar(notifier),
      ],
    );
  }

  Widget _buildCompensationBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: const Color(0xFFF5CC70)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Color(0xFFB8860B), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('보상동작 감지',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF856404),
                    )),
                Text('자세를 바로 잡아주세요',
                    style: TextStyle(
                        fontSize: 11, color: Color(0xFF856404))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmgCard(RealtimeNotifier notifier) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        color: AppTheme.bgDark,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EMG 신호',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondaryDark,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            child: EmgWaveform(
              samples: notifier.ch1Wave,
              color: AppTheme.primary,
              label: '',
              height: 50,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatGrid(dynamic state) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: [
        _SessionStatCard(
            label: '총 반복',
            value: '${state.repCount}',
            color: AppTheme.primary),
        _SessionStatCard(
            label: '보상동작',
            value: '${state.compensationCount}',
            color: AppTheme.warning),
        _SessionStatCard(
            label: '현재 세트',
            value: '$_currentSet / ${_currentItem.sets}',
            color: AppTheme.success),
        _SessionStatCard(
            label: '경과 시간',
            value: _elapsedLabel,
            color: AppTheme.accent),
      ],
    );
  }

  Widget _buildActionBar(RealtimeNotifier notifier) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: GradientButton(
                label: '+ 반복',
                gradient: AppGradients.action,
                height: 52,
                onPressed: notifier.addRep,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _phase = _Phase.resting),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTokens.radiusMd),
                  ),
                ),
                child: const Text('휴식'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GradientButton(
                label: '완료',
                gradient: AppGradients.primary,
                height: 52,
                onPressed: _finishSet,
              ),
            ),
          ],
        ),
      ),
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

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _SessionStatCard extends StatelessWidget {
  const _SessionStatCard({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
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
