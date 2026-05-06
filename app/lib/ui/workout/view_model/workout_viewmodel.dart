import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/workout_repository.dart';

class WorkoutViewModel {
  WorkoutViewModel(this._workoutRepository);

  final WorkoutRepository _workoutRepository;
  StreamSubscription? _pausedSubscription;
  StreamSubscription? _resumedSubscription;

  void startListening({
    required VoidCallback onPaused,
    required VoidCallback onResumed,
  }) {
    _pausedSubscription ??= _workoutRepository.workoutPaused.listen((_) {
      onPaused();
    });
    _resumedSubscription ??= _workoutRepository.workoutResumed.listen((_) {
      onResumed();
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
    _pausedSubscription?.cancel();
    _resumedSubscription?.cancel();
  }
}
