import '../../../data/repositories/workout_repository.dart';

class WorkoutViewModel {
  WorkoutViewModel(this._workoutRepository);

  final WorkoutRepository _workoutRepository;

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
}
