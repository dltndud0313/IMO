import 'dart:async';

import '../../data/repositories/local_session_repository.dart';
import '../../data/repositories/session_history_repository.dart';
import '../../domain/repositories/workout_repository_interface.dart';

class EndWorkoutSessionUseCase {
  EndWorkoutSessionUseCase(
    this._workoutRepo,
    this._historyRepo,
    this._localSessionRepo,
  );

  final IWorkoutRepository _workoutRepo;
  final SessionHistoryRepository _historyRepo;
  final LocalSessionRepository _localSessionRepo;
  StreamSubscription<void>? _autoSaveSubscription;

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
    final existingSubscription = _autoSaveSubscription;
    if (existingSubscription != null) {
      return existingSubscription;
    }

    final subscription = _workoutRepo.sessionResultMessages
        .asyncMap((message) async {
          final session = message.session;

          await _localSessionRepo.saveSessionResult(
            session,
            rawPayload: message.payload,
          );

          try {
            await _historyRepo.saveSession(session);
            await _localSessionRepo.markSynced(session.sessionId);
          } catch (_) {
            await _localSessionRepo.markFailed(session.sessionId);
          }
        })
        .listen((_) {});
    _autoSaveSubscription = subscription;
    return subscription;
  }
}
