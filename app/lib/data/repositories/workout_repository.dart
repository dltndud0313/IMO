import '../../domain/models/workout_session.dart';
import '../services/pi_message.dart';
import '../services/pi_socket_service.dart';

class WorkoutRepository {
  WorkoutRepository(this._socket);

  final PiSocketService _socket;

  Stream<PlanAckMessage> get planAck =>
      _socket.messagesOf<PlanAckMessage>();

  Stream<WorkoutStartedMessage> get workoutStarted =>
      _socket.messagesOf<WorkoutStartedMessage>();

  Stream<WorkoutPausedMessage> get workoutPaused =>
      _socket.messagesOf<WorkoutPausedMessage>();

  Stream<WorkoutResumedMessage> get workoutResumed =>
      _socket.messagesOf<WorkoutResumedMessage>();

  Stream<SetCompletedMessage> get setCompleted =>
      _socket.messagesOf<SetCompletedMessage>();

  Stream<RestStartedMessage> get restStarted =>
      _socket.messagesOf<RestStartedMessage>();

  Stream<RestFinishedMessage> get restFinished =>
      _socket.messagesOf<RestFinishedMessage>();

  Stream<WorkoutCompletedMessage> get workoutCompleted =>
      _socket.messagesOf<WorkoutCompletedMessage>();

  Stream<WorkoutSession> get sessionResult =>
      _socket.messagesOf<SessionResultMessage>().map((message) {
        return message.session;
      });

  Future<void> connect() {
    return _socket.connect();
  }

  void submitWorkoutPlan({
    required String exerciseType,
    required int setCount,
    required List<int> targetRepsPerSet,
    required int restSec,
  }) {
    _socket.submitWorkoutPlan(
      exerciseType: exerciseType,
      setCount: setCount,
      targetRepsPerSet: targetRepsPerSet,
      restSec: restSec,
    );
  }

  void pauseWorkout() {
    _socket.pauseWorkout();
  }

  void resumeWorkout() {
    _socket.resumeWorkout();
  }

  void stopWorkout({
    String reason = 'user_request',
    bool saveResult = true,
  }) {
    _socket.stopWorkout(
      reason: reason,
      saveResult: saveResult,
    );
  }

  void emergencyStop() {
    _socket.emergencyStop();
  }
}
