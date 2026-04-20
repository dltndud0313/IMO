import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/exercise.dart';
import '../models/pose_data.dart';
import '../models/realtime_state.dart';
import '../providers/realtime_provider.dart';
import '../services/profile_storage.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_painter.dart';
import '../widgets/emg_waveform.dart';
import '../widgets/speed_indicator.dart';
import '../widgets/compensation_overlay.dart';
import '../widgets/fatigue_banner.dart';
import 'result_screen.dart';

class RemoteScreen extends ConsumerStatefulWidget {
  final Exercise exercise;
  final int? targetReps;
  const RemoteScreen({super.key, required this.exercise, this.targetReps});

  @override
  ConsumerState<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends ConsumerState<RemoteScreen>
    with SingleTickerProviderStateMixin {
  PoseData? _pose;
  int _prevRepCount = 0;
  bool _prevCompensation = false;

  // rep 카운트 bounce 애니메이션
  late final AnimationController _bounceCtrl;
  late final Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _loadPose();
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

  void _onStateUpdate(RealtimeState state) {
    // rep 증가 시 bounce + 햅틱
    if (state.repCount > _prevRepCount && _prevRepCount > 0) {
      _bounceCtrl.forward(from: 0);
      if (SettingsService().hapticEnabled) {
        HapticFeedback.lightImpact();
      }
    }
    // 보상작용 감지 시 강한 햅틱
    if (state.isCompensation && !_prevCompensation) {
      if (SettingsService().hapticEnabled) {
        HapticFeedback.heavyImpact();
      }
    }
    _prevRepCount = state.repCount;
    _prevCompensation = state.isCompensation;
  }

  Future<void> _loadPose() async {
    final pose = await ProfileStorage().loadPose();
    if (!mounted) return;
    setState(() => _pose = pose);
  }

  void _start() {
    ref.read(realtimeProvider.notifier).start();
  }

  void _stopAndShowResult() {
    final state = ref.read(realtimeProvider);
    ref.read(realtimeProvider.notifier).stop();

    final result = SessionResult(
      totalReps: state.repCount,
      compensationCount: state.isCompensation ? 1 : 0,
      avgCh1: state.ch1,
      avgCh2: state.ch2,
      avgCh3: state.ch3,
      comment: state.repCount > 0
          ? '총 ${state.repCount}회 운동을 완료했습니다. 좋은 자세를 유지해보세요!'
          : '다음에는 조금 더 해보세요!',
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          exercise: widget.exercise,
          result: result,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(realtimeProvider);
    _onStateUpdate(state);
    final notifier = ref.read(realtimeProvider.notifier);
    final running = notifier.isRunning;
    final ch = widget.exercise.channels;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exercise.name),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (running) notifier.stop();
            Navigator.pop(context);
          },
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (state.isFatigued) const FatigueBanner(),
                  const SizedBox(height: 16),
                  const Text(
                    '반복 횟수',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ScaleTransition(
                    scale: _bounceAnim,
                    child: Text(
                      widget.targetReps != null
                          ? '${state.repCount} / ${widget.targetReps}'
                          : '${state.repCount}',
                      style: const TextStyle(
                        fontSize: 100,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                        height: 1,
                      ),
                    ),
                  ),
                  if (widget.targetReps != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (state.repCount / widget.targetReps!)
                            .clamp(0.0, 1.0),
                        minHeight: 10,
                        backgroundColor: AppTheme.border,
                        valueColor: const AlwaysStoppedAnimation(
                            AppTheme.primary),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SpeedIndicator(speed: state.speed),
                  const SizedBox(height: 12),
                  if (running)
                    EmgWaveform(
                      samples: notifier.ch1Wave,
                      color: AppTheme.primary,
                      label: '${ch.ch1Name} 실시간 EMG',
                      height: 70,
                    ),
                  const SizedBox(height: 12),
                  // 아바타
                  if (_pose != null)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: CustomPaint(
                          painter: AvatarPainter(
                            pose: _pose!,
                            regions: running
                                ? {
                                    ch.ch1Region: MuscleChannel(
                                      label: 'CH1',
                                      muscleName: ch.ch1Name,
                                      intensity: state.ch1 / 100,
                                    ),
                                    ch.ch2Region: MuscleChannel(
                                      label: 'CH2',
                                      muscleName: ch.ch2Name,
                                      intensity: state.ch2 / 100,
                                    ),
                                    ch.ch3Region: MuscleChannel(
                                      label: 'CH3',
                                      muscleName: ch.ch3Name,
                                      intensity: state.ch3 / 100,
                                    ),
                                  }
                                : const {},
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  const SizedBox(height: 12),
                  // EMG 채널 미니 디스플레이
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _ChannelChip(label: ch.ch1Name, value: state.ch1),
                          _ChannelChip(label: ch.ch2Name, value: state.ch2),
                          _ChannelChip(label: ch.ch3Name, value: state.ch3),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (!running)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _start,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('시작'),
                          ),
                        )
                      else ...[
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
                            icon: Icon(notifier.isPaused
                                ? Icons.play_arrow
                                : Icons.pause),
                            label: Text(
                                notifier.isPaused ? '재개' : '일시정지'),
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
                            onPressed: _stopAndShowResult,
                            icon: const Icon(Icons.stop),
                            label: const Text('종료'),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          if (state.isCompensation) const CompensationOverlay(),
        ],
      ),
    );
  }
}

class _ChannelChip extends StatelessWidget {
  final String label;
  final double value;
  const _ChannelChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.toStringAsFixed(1),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
