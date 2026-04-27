import 'dart:async';

import '../../data/repositories/session_history_repository.dart';
import '../../data/repositories/workout_repository.dart';

/// 운동 세션 종료 플로우 (수동/자동 종료 후 서버에 저장)
class EndWorkoutSessionUseCase {
  final WorkoutRepository _workoutRepo;
  final SessionHistoryRepository _historyRepo;

  EndWorkoutSessionUseCase(this._workoutRepo, this._historyRepo);

  /// 사용자가 수동으로 종료 요청 시
  Future<void> stopManually(String reason) async {
    final stopped = await _workoutRepo.stopExercise(reason);
    if (!stopped) {
      // 강제 종료 처리 등 추가
    }
    // STOP을 던지면 Pi에서 부분 데이터를 취합해 EXERCISE_COMPLETED를 
    // 보내줄 것이므로, 저장은 그 이벤트를 수신할 때 처리한다.
  }

  /// 백그라운드나 뷰모델 초기화 때 호출해두면 EXERCISE_COMPLETED 수신 시 자동 저장
  StreamSubscription<void>? listenAndSaveAutomatically() {
    return _workoutRepo.exerciseCompleted.listen((sessionData) async {
      try {
        await _historyRepo.saveSession(sessionData);
      } catch (e) {
        // 에러 로깅
      }
    });
  }
}
