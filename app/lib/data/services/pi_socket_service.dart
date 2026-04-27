import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'pi_message.dart';

/// 1페이지 요약본 규격에 맞춘 Pi WebSocket 연결 서비스
class PiSocketService {
  WebSocketChannel? _channel;
  final String _url;
  
  // 수신된 10종의 이벤트를 앱 내부에 브로드캐스팅하는 스트림
  final _messageController = StreamController<PiMessage>.broadcast();
  Stream<PiMessage> get messageStream => _messageController.stream;

  bool get isConnected => _channel != null;

  PiSocketService({String url = 'ws://192.168.0.100:8765'}) : _url = url;

  Future<void> connect() async {
    if (isConnected) return;
    try {
      final uri = Uri.parse(_url);
      _channel = WebSocketChannel.connect(uri);
      
      _channel!.stream.listen(
        (data) {
          try {
            final jsonMap = jsonDecode(data as String) as Map<String, dynamic>;
            final message = PiMessage.tryParse(jsonMap);
            if (message != null) {
              log('📥 [Pi Socket Received] ${message.type}');
              _messageController.add(message);
            } else {
              log('⚠️ [Pi Socket] 파싱 실패 또는 무시된 이벤트: $data');
            }
          } catch (e) {
            log('🚨 [Pi Socket Error] JSON 해석 실패: $e\nData: $data');
          }
        },
        onError: (error) {
          log('🚨 [Pi Socket Error] 연결 오류 발생: $error');
          _disconnectInternal();
        },
        onDone: () {
          log('🔌 [Pi Socket] Pi와의 연결이 종료되었습니다.');
          _disconnectInternal();
        },
      );
      log('✅ [Pi Socket] 연결 완료: $_url');
    } catch (e) {
      log('🚨 [Pi Socket Error] 연결 실패: $e');
      rethrow;
    }
  }

  void _disconnectInternal() {
    _channel?.sink.close();
    _channel = null;
  }

  void disconnect() {
    _disconnectInternal();
  }

  /// 공통 메시지 전송 로직
  void _send(String type, Map<String, dynamic> payload) {
    if (!isConnected) {
      log('⚠️ [Pi Socket Error] 전송 불가: Socket 연결 안 됨');
      return;
    }
    final frame = {
      'type': type,
      'payload': payload,
    };
    log('📤 [Pi Socket Send] $type');
    _channel!.sink.add(jsonEncode(frame));
  }

  // ═══════════════════════════════════════════════════════════
  //  App → Pi 발신 함수들 (주로 제어 명령 처리)
  // ═══════════════════════════════════════════════════════════

  /// 3-1. 운동 선택 및 계획(세트/횟수/휴식시간) 병합 전송
  void submitWorkoutPlan({
    required String exerciseType,
    required int setCount,
    required List<int> targetRepsPerSet,
    required int restSec,
  }) {
    _send('submit_workout_plan', {
      'exercise_type': exerciseType,
      'set_count': setCount,
      'target_reps_per_set': targetRepsPerSet,
      'rest_sec': restSec,
    });
  }

  /// 3-2. 캘리브레이션 시작 측정 명령어
  void startCalibration(String exerciseType) {
    _send('start_calibration', {
      'exercise_type': exerciseType,
    });
  }

  /// 3-4. 비상 중지 (즉각 근 활성도 한계점 등에서 기기 차단용)
  void emergencyStop({String reason = 'user_emergency'}) {
    _send('emergency_stop', {'reason': reason});
  }

  /// 3-5. 사용자에 의한 일반 운동 중단
  void stopWorkout({String reason = 'user_request', bool saveResult = true}) {
    _send('stop_workout', {
      'reason': reason,
      'save_result': saveResult,
    });
  }

  /// 3-6. 운동 중단 (전화왔거나 휴식)
  void pauseWorkout({String reason = 'user_request'}) {
    _send('pause_workout', {
      'reason': reason,
    });
  }

  /// 3-7. 운동 재개
  void resumeWorkout({String reason = 'user_request'}) {
    _send('resume_workout', {
      'reason': reason,
    });
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
