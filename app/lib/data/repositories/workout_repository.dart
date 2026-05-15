import '../../domain/models/workout_session.dart';
import '../../domain/repositories/workout_repository_interface.dart';
import '../services/pi_message.dart';
import '../services/pi_socket_service.dart';

class WorkoutRepository implements IWorkoutRepository {
  WorkoutRepository(this._socket);

  final PiSocketService _socket;

  @override
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

  Stream<WorkoutEventMessage> get workoutEvents =>
      _socket.messagesOf<WorkoutEventMessage>();

  @override
  Stream<SessionResultMessage> get sessionResultMessages =>
      _socket.messagesOf<SessionResultMessage>();

  Stream<WorkoutSession> get sessionResult =>
      sessionResultMessages.map((message) {
        return message.session;
      });

  Future<void> connect() {
    return _socket.connect();
  }

  @override
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

  @override
  void startWorkout() {
    _socket.startWorkout();
  }

  @override
  void pauseWorkout() {
    _socket.pauseWorkout();
  }

  @override
  void resumeWorkout() {
    _socket.resumeWorkout();
  }

  @override
  void stopWorkout({
    String reason = 'user_request',
    bool saveResult = true,
  }) {
    _socket.stopWorkout(
      reason: reason,
      saveResult: saveResult,
    );
  }

  @override
  void emergencyStop() {
    _socket.emergencyStop();
  }
}
