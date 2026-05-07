import 'package:flutter/foundation.dart';

import '../../../data/repositories/session_history_repository.dart';
import '../../../domain/models/workout_session.dart';

class HistoryViewModel extends ChangeNotifier {
  HistoryViewModel(this._repository);

  final SessionHistoryRepository _repository;

  List<WorkoutSession> daySessions = const [];
  bool loadingSessions = true;
  String? sessionLoadError;

  Future<void> loadSessionsByDate(String dateText) async {
    loadingSessions = true;
    sessionLoadError = null;
    notifyListeners();

    try {
      daySessions = await _repository.getSessionsByDate(dateText);
    } catch (_) {
      daySessions = const [];
      sessionLoadError = '운동 기록을 불러오지 못했습니다.';
    } finally {
      loadingSessions = false;
      notifyListeners();
    }
  }
}
