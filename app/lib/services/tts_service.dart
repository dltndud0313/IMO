import 'package:flutter_tts/flutter_tts.dart';

import '../models/realtime_state.dart';
import 'settings_service.dart';

/// TTS 음성 피드백 서비스.
/// 반복 수, 보상동작, 속도, 피로 등 상태 변화 시 음성 안내.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  // 중복 안내 방지용
  int _lastSpokenRep = -1;
  bool _lastCompensation = false;
  bool _lastFatigued = false;
  RepSpeed? _lastSpeed;

  Future<void> init() async {
    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _ready = true;
  }

  Future<void> _speak(String text) async {
    if (!_ready || !SettingsService().ttsEnabled) return;
    await _tts.speak(text);
  }

  /// 실시간 상태 변화에 따라 적절한 음성 피드백 호출.
  /// remote_screen에서 setState 후 호출.
  void onStateChanged(RealtimeState state) {
    // 반복 수 (매 회)
    if (state.repCount > 0 && state.repCount != _lastSpokenRep) {
      _lastSpokenRep = state.repCount;
      _speak('${state.repCount}회');
    }

    // 보상동작 감지
    if (state.isCompensation && !_lastCompensation) {
      _speak('자세를 교정해주세요');
    }
    _lastCompensation = state.isCompensation;

    // 속도 변화
    if (state.speed != _lastSpeed) {
      _lastSpeed = state.speed;
      switch (state.speed) {
        case RepSpeed.fast:
          _speak('천천히 해주세요');
          break;
        case RepSpeed.slow:
          _speak('조금 더 빠르게');
          break;
        case RepSpeed.normal:
          break;
      }
    }

    // 근피로
    if (state.isFatigued && !_lastFatigued) {
      _speak('휴식이 필요해요');
    }
    _lastFatigued = state.isFatigued;
  }

  /// 운동 종료 시 호출
  Future<void> onSessionEnd() async {
    await _speak('운동 완료. 수고하셨습니다');
  }

  /// 상태 초기화 (새 세션 시작 시)
  void reset() {
    _lastSpokenRep = -1;
    _lastCompensation = false;
    _lastFatigued = false;
    _lastSpeed = null;
  }

  Future<void> dispose() async {
    await _tts.stop();
  }
}
