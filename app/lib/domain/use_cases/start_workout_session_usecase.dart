import '../models/exercise_plan.dart';
import '../../data/repositories/workout_repository.dart';
import 'check_system_ready_usecase.dart';

/// 운동 세션 시작 플로우 (목표 설정 -> 시스템 확인 -> 전송 -> 시작)
class StartWorkoutSessionUseCase {
  final WorkoutRepository _workoutRepo;
  final CheckSystemReadyUseCase _checkReady;

  StartWorkoutSessionUseCase(this._workoutRepo, this._checkReady);

  /// 1. 시스템 준비 확인 후
  /// 2. 운동 계획 Pi로 전송 (EXERCISE_PLAN_SEND)
  /// 3. 운동 세션 시작 명령 (EXERCISE_START)
  Future<void> execute(ExercisePlan plan) async {
    final isReady = await _checkReady.execute();
    if (!isReady) {
      throw Exception('시스템 준비가 완료되지 않았습니다. 센서 연결 및 캘리브레이션을 확인하세요.');
    }

    final planAccepted = await _workoutRepo.sendExercisePlan(plan);
    if (!planAccepted) {
      throw Exception('운동 계획 전송 실패 또는 유효하지 않은 계획입니다.');
    }

    final startSuccess = await _workoutRepo.startExercise();
    if (!startSuccess) {
      throw Exception('운동 시작 명령 전달 실패');
    }
  }
}
