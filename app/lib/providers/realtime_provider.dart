import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/realtime_state.dart';
import '../services/tts_service.dart';

/// 실시간 운동 상태를 관리하는 StateNotifier.
/// mock 타이머로 시뮬레이션. 추후 WebSocket 스트림으로 교체.
class RealtimeNotifier extends StateNotifier<RealtimeState> {
  Timer? _timer;
  Timer? _waveTimer;
  final TtsService _tts = TtsService();
  bool _running = false;
  bool _paused = false;

  /// 최근 ~10초 EMG 파형 샘플 (0~100 정규화). 길이 100 고정.
  static const int waveLength = 100;
  final List<double> _ch1Wave = List.filled(waveLength, 0);
  List<double> get ch1Wave => List.unmodifiable(_ch1Wave);

  RealtimeNotifier() : super(RealtimeState.empty) {
    _tts.init();
  }

  bool get isRunning => _running;
  bool get isPaused => _paused;

  void start() {
    _tts.reset();
    _running = true;
    _paused = false;
    state = RealtimeState.empty;
    _ch1Wave.fillRange(0, waveLength, 0);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_paused) return;
      final next = state.repCount + 1;
      state = RealtimeState(
        repCount: next,
        speed: next % 8 == 0 ? RepSpeed.fast : RepSpeed.normal,
        isCompensation: next % 5 == 0,
        isFatigued: next >= 10,
        ch1: 70 + (next % 5) * 2,
        ch2: 45 + (next % 3) * 2,
        ch3: 30 + (next % 4),
      );
      _tts.onStateChanged(state);
    });
    // 파형 샘플링 — 100ms마다 ch1값을 buffer에 push (ring)
    _waveTimer =
        Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (_paused) return;
      final tick = t.tick;
      final base = state.ch1;
      // 기본값 + 싸인파로 자연스러운 waveform 시뮬레이션
      final sample =
          (base + 8 * (0.5 + 0.5 * _fakeOsc(tick))).clamp(0.0, 100.0);
      _ch1Wave.removeAt(0);
      _ch1Wave.add(sample.toDouble());
    });
  }

  double _fakeOsc(int tick) {
    // 0~1 사이 진동
    final v = (tick % 10) / 10.0;
    return v < 0.5 ? v * 2 : 2 - v * 2;
  }

  void pause() {
    if (!_running) return;
    _paused = true;
  }

  void resume() {
    if (!_running) return;
    _paused = false;
  }

  void stop() {
    _timer?.cancel();
    _waveTimer?.cancel();
    _running = false;
    _paused = false;
    _tts.onSessionEnd();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _waveTimer?.cancel();
    _tts.dispose();
    super.dispose();
  }
}

/// autoDispose → 화면 벗어나면 자동 정리
final realtimeProvider =
    StateNotifierProvider.autoDispose<RealtimeNotifier, RealtimeState>(
  (ref) => RealtimeNotifier(),
);
