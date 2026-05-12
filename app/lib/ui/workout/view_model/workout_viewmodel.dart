import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/device_connection_repository.dart';
import '../../../data/repositories/workout_repository.dart';
import '../../../data/services/pi_message.dart';
import '../../../domain/models/workout_session.dart';

class WorkoutViewModel {
  WorkoutViewModel(
    this._workoutRepository,
    this._deviceConnectionRepository,
  );

  final WorkoutRepository _workoutRepository;
  final DeviceConnectionRepository _deviceConnectionRepository;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _pausedSubscription;
  StreamSubscription? _resumedSubscription;
  StreamSubscription? _sessionResultSubscription;

  void startListening({
    required ValueChanged<ConnectionStatusMessage> onConnectionStatus,
    required VoidCallback onPaused,
    required VoidCallback onResumed,
    required ValueChanged<WorkoutSession> onSessionResult,
  }) {
    _connectionSubscription ??=
        _deviceConnectionRepository.systemStatus.listen((status) {
      onConnectionStatus(status);
    });
    _pausedSubscription ??= _workoutRepository.workoutPaused.listen((_) {
      onPaused();
    });
    _resumedSubscription ??= _workoutRepository.workoutResumed.listen((_) {
      onResumed();
    });
    _sessionResultSubscription ??=
        _workoutRepository.sessionResult.listen((session) {
      onSessionResult(session);
    });
  }

  void pauseWorkout() {
    _workoutRepository.pauseWorkout();
  }

  void resumeWorkout() {
    _workoutRepository.resumeWorkout();
  }

  void stopWorkout({
    String reason = 'user_request',
    bool saveResult = true,
  }) {
    _workoutRepository.stopWorkout(
      reason: reason,
      saveResult: saveResult,
    );
  }

  void emergencyStop() {
    _workoutRepository.emergencyStop();
  }

  void dispose() {
    _connectionSubscription?.cancel();
    _pausedSubscription?.cancel();
    _resumedSubscription?.cancel();
    _sessionResultSubscription?.cancel();
  }
}
