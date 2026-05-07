import '../../../data/repositories/calibration_repository.dart';
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
  WorkoutSetupViewModel(WorkoutRepository workoutRepository)
      : _workoutRepository = workoutRepository,
        _calibrationRepository = null;

  WorkoutSetupViewModel.withCalibration(
    CalibrationRepository calibrationRepository,
  )   : _workoutRepository = null,
        _calibrationRepository = calibrationRepository;

  final WorkoutRepository? _workoutRepository;
  final CalibrationRepository? _calibrationRepository;

  Future<WorkoutPlanSubmitResult> submitWorkoutPlan({
    required String exerciseType,
    required int setCount,
    required List<int> targetRepsPerSet,
    required int restSec,
  }) async {
    final workoutRepository = _workoutRepository;
    if (workoutRepository == null) {
      throw StateError('WorkoutRepository is required.');
    }

    await workoutRepository.connect();
    workoutRepository.submitWorkoutPlan(
      exerciseType: exerciseType,
      setCount: setCount,
      targetRepsPerSet: targetRepsPerSet,
      restSec: restSec,
    );

    final ack = await workoutRepository.planAck
        .map<Object?>((message) => message)
        .first
        .timeout(const Duration(seconds: 5), onTimeout: () => null);
    if (ack is PlanAckMessage && !ack.accepted) {
      return WorkoutPlanSubmitResult.rejected(ack.validationErrors);
    }

    return const WorkoutPlanSubmitResult.accepted();
  }

  Future<void> completeSensorAttachmentAndStartCalibration({
    required String exerciseType,
  }) async {
    final calibrationRepository = _calibrationRepository;
    if (calibrationRepository == null) {
      throw StateError('CalibrationRepository is required.');
    }

    await calibrationRepository.connect();
    calibrationRepository.markSensorsAttached();
    calibrationRepository.startCalibration(exerciseType: exerciseType);
  }
}
