import '../../domain/repositories/workout_repository_interface.dart';
import 'check_system_ready_usecase.dart';

class StartWorkoutPlan {
  const StartWorkoutPlan({
    required this.exerciseType,
    required this.setCount,
    required this.targetRepsPerSet,
    required this.restSec,
  });

  final String exerciseType;
  final int setCount;
  final List<int> targetRepsPerSet;
  final int restSec;
}

class StartWorkoutSessionUseCase {
  StartWorkoutSessionUseCase(this._workoutRepo, this._checkReady);

  final IWorkoutRepository _workoutRepo;
  final CheckSystemReadyUseCase _checkReady;

  Future<void> execute(StartWorkoutPlan plan) async {
    final isReady = await _checkReady.execute();
    if (!isReady) {
      throw StateError('System is not ready to start workout.');
    }

    _workoutRepo.submitWorkoutPlan(
      exerciseType: plan.exerciseType,
      setCount: plan.setCount,
      targetRepsPerSet: plan.targetRepsPerSet,
      restSec: plan.restSec,
    );

    final ack = await _workoutRepo.planAck.first;
    if (!ack.accepted) {
      throw StateError(
        ack.validationErrors.isEmpty
            ? 'Workout plan was rejected.'
            : ack.validationErrors.join(', '),
      );
    }
  }
}
