import '../../../data/repositories/workout_repository.dart';
import '../../../data/services/pi_message.dart';

class WorkoutPlanSubmitResult {
  const WorkoutPlanSubmitResult._({
    required this.accepted,
    this.validationErrors = const [],
  });

  const WorkoutPlanSubmitResult.accepted()
      : this._(accepted: true);

  const WorkoutPlanSubmitResult.rejected(List<String> validationErrors)
      : this._(accepted: false, validationErrors: validationErrors);

  final bool accepted;
  final List<String> validationErrors;
}

class WorkoutSetupViewModel {
  WorkoutSetupViewModel(this._workoutRepository);

  final WorkoutRepository _workoutRepository;

  Future<WorkoutPlanSubmitResult> submitWorkoutPlan({
    required String exerciseType,
    required int setCount,
    required List<int> targetRepsPerSet,
    required int restSec,
  }) async {
    await _workoutRepository.connect();
    _workoutRepository.submitWorkoutPlan(
      exerciseType: exerciseType,
      setCount: setCount,
      targetRepsPerSet: targetRepsPerSet,
      restSec: restSec,
    );

    final ack = await _workoutRepository.planAck
        .map<Object?>((message) => message)
        .first
        .timeout(const Duration(seconds: 5), onTimeout: () => null);
    if (ack is PlanAckMessage && !ack.accepted) {
      return WorkoutPlanSubmitResult.rejected(ack.validationErrors);
    }

    return const WorkoutPlanSubmitResult.accepted();
  }
}
