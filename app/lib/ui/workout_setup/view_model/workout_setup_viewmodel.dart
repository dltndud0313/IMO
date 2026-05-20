import 'dart:async';

import '../../../data/repositories/calibration_repository.dart';
import '../../../data/repositories/workout_repository.dart';
import '../../../data/services/pi_message.dart';

/// 캘리브레이션 진행 단계.
///
/// Pi는 REST 측정 시작과 MVC 측정 시작을 모두 `status="started"`로 보내기 때문에
/// 앱에서 한 번의 캘리브레이션 동안 들어온 `started` 횟수로 두 단계를 구분한다.
enum CalibrationStage { measuringRest, measuringMvc, success, failed }

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
  int _calibrationStartedCount = 0;

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
    if (ack == null) {
      return WorkoutPlanSubmitResult.rejected(
        ['Pi가 응답하지 않습니다. 연결 상태를 확인하세요.'],
      );
    }
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

    _calibrationStartedCount = 0;
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

    _calibrationStartedCount = 0;
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

  /// 캘리브레이션 단계 변화를 구독한다.
  ///
  /// Pi는 REST/MVC 측정 시작을 모두 `status="started"`로 보내므로, 한 번의
  /// 캘리브레이션 동안 첫 번째 `started`는 [CalibrationStage.measuringRest],
  /// 두 번째는 [CalibrationStage.measuringMvc]로 해석한다. 카운터는 새 캘리브레이션을
  /// 시작할 때(startCalibration 등)와 success/failed 수신 시 0으로 초기화된다.
  void listenCalibrationStatus({
    required void Function(CalibrationStage stage) onStage,
    void Function(CalibrationStatusMessage status)? onStatus,
  }) {
    final calibrationRepository = _calibrationRepository;
    if (calibrationRepository == null) {
      throw StateError('CalibrationRepository is required.');
    }

    _calibrationStatusSubscription?.cancel();
    _calibrationStartedCount = 0;
    _calibrationStatusSubscription = calibrationRepository.status.listen((
      status,
    ) {
      onStatus?.call(status);
      if (status.isStarted) {
        _calibrationStartedCount++;
        onStage(
          _calibrationStartedCount <= 1
              ? CalibrationStage.measuringRest
              : CalibrationStage.measuringMvc,
        );
      } else if (status.isSuccess) {
        _calibrationStartedCount = 0;
        onStage(CalibrationStage.success);
      } else if (status.isFailed) {
        _calibrationStartedCount = 0;
        onStage(CalibrationStage.failed);
      }
    });
  }

  void dispose() {
    _calibrationStatusSubscription?.cancel();
    _calibrationStatusSubscription = null;
  }
}
