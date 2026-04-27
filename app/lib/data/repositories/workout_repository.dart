import 'dart:async';

import '../../domain/models/coaching_message.dart';
import '../../domain/models/exercise_plan.dart';
import '../../domain/models/realtime_feedback.dart';
import '../../domain/models/set_result.dart';
import '../../domain/models/workout_session.dart';
import '../services/pi_message.dart';
import '../services/pi_socket_service.dart';

/// 실시간 운동 피드백 Stream + 운동 계획 전송
class WorkoutRepository {
  final PiSocketService _socket;

  WorkoutRepository(this._socket);

  // ─── WebSocket 수신 (도메인 모델로 매핑) ───

  Stream<RealtimeFeedback> get realtimeData =>
      _socket.realtimeData.map((m) => m.feedback);

  Stream<RepCompletedEvent> get repCompleted =>
      _socket.repCompleted.map((m) => m.event);

  Stream<SetCompletedEvent> get setCompleted =>
      _socket.setCompleted.map((m) => m.event);

  Stream<RestTimerEvent> get restTimer =>
      _socket.restTimer.map((m) => m.event);

  Stream<WorkoutSession> get exerciseCompleted =>
      _socket.exerciseCompleted.map((m) => m.session);

  Stream<CoachingMessage> get coaching =>
      _socket.coaching.map((m) => m.coaching);

  // ─── App → Pi 송신 ───

  /// 운동 계획 전송 후 ACK 수신할 때까지 대기
  Future<bool> sendExercisePlan(ExercisePlan plan) async {
    _socket.sendExercisePlan(plan);
    try {
      final ack = await _socket.exercisePlanAck.firstWhere(
        (msg) => true, // 모든 ACK를 기다림 (단일 세션 가정)
      ).timeout(const Duration(seconds: 5));
      
      if (!ack.accepted) {
        // Validation Errors 처리 (간략화)
        throw Exception(ack.validationErrors.map((e) => e.reason).join(', '));
      }
      return true;
    } catch (e) {
      if (e is TimeoutException) return false;
      rethrow;
    }
  }

  /// 운동 시작 요청
  Future<bool> startExercise() async {
    _socket.sendExerciseStart();
    try {
      final ack = await _socket.exerciseStartAck.first.timeout(const Duration(seconds: 5));
      return ack.started;
    } catch (_) {
      return false;
    }
  }

  /// 운동 수동 종료 요청
  Future<bool> stopExercise(String reason) async {
    _socket.sendExerciseStop(reason: reason);
    try {
      final ack = await _socket.exerciseStopAck.first.timeout(const Duration(seconds: 5));
      return ack.stopped;
    } catch (_) {
      return false;
    }
  }
}
