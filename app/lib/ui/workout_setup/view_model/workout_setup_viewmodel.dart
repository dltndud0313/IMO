import 'dart:async';

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
    CalibrationRepository calibrationRepository, {
    WorkoutRepository? workoutRepository,
  })  : _workoutRepository = workoutRepository,
        _calibrationRepository = calibrationRepository;

  final WorkoutRepository? _workoutRepository;
  final CalibrationRepository? _calibrationRepository;
  StreamSubscription? _calibrationStatusSubscription;

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
    // Pi 상태머신이 sensors_attached 처리(phase 전환)를 끝낼 시간을 준다.
    // 간격 없이 start_calibration을 보내면 캘리브레이션 collection이 시작되지 않음.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    calibrationRepository.startCalibration(exerciseType: exerciseType);
  }

  Future<void> startCalibration({
    required String exerciseType,
  }) async {
    final calibrationRepository = _calibrationRepository;
    if (calibrationRepository == null) {
      throw StateError('CalibrationRepository is required.');
    }

    await calibrationRepository.connect();
    calibrationRepository.startCalibration(exerciseType: exerciseType);
  }

  Future<void> startWorkout() async {
    final workoutRepository = _workoutRepository;
    if (workoutRepository == null) {
      throw StateError('WorkoutRepository is required.');
    }

    await workoutRepository.connect();
    workoutRepository.startWorkout();
  }

  void listenCalibrationStatus({
    required void Function() onStarted,
    required void Function() onSuccess,
    required void Function() onFailed,
  }) {
    final calibrationRepository = _calibrationRepository;
    if (calibrationRepository == null) {
      throw StateError('CalibrationRepository is required.');
    }

    _calibrationStatusSubscription?.cancel();
    _calibrationStatusSubscription = calibrationRepository.status.listen((
      status,
    ) {
      if (status.isStarted) {
        onStarted();
      } else if (status.isSuccess) {
        onSuccess();
      } else if (status.isFailed) {
        onFailed();
      }
    });
  }

  void dispose() {
    _calibrationStatusSubscription?.cancel();
    _calibrationStatusSubscription = null;
  }
}
