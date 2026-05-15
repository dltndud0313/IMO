import '../../data/services/pi_message.dart';

abstract interface class IWorkoutRepository {
  Stream<PlanAckMessage> get planAck;
  Stream<SessionResultMessage> get sessionResultMessages;

  void submitWorkoutPlan({
    required String exerciseType,
    required int setCount,
    required List<int> targetRepsPerSet,
    required int restSec,
  });

  void startWorkout();

  void stopWorkout({
    String reason = 'user_request',
    bool saveResult = true,
  });

  void pauseWorkout();
  void resumeWorkout();
  void emergencyStop();
}
