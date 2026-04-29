import 'dart:async';

import '../../data/repositories/session_history_repository.dart';
import '../../data/repositories/workout_repository.dart';

class EndWorkoutSessionUseCase {
  EndWorkoutSessionUseCase(this._workoutRepo, this._historyRepo);

  final WorkoutRepository _workoutRepo;
  final SessionHistoryRepository _historyRepo;

  void stopManually({
    String reason = 'user_request',
    bool saveResult = true,
  }) {
    _workoutRepo.stopWorkout(
      reason: reason,
      saveResult: saveResult,
    );
  }

  StreamSubscription<void> listenAndSaveAutomatically() {
    return _workoutRepo.sessionResult.asyncMap((session) async {
      await _historyRepo.saveSession(session);
    }).listen((_) {});
  }
}
