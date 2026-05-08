import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateUtils;

import '../../../data/repositories/session_history_repository.dart';
import '../../../domain/models/workout_session.dart';

class HistoryViewModel extends ChangeNotifier {
  HistoryViewModel(this._repository);

  final SessionHistoryRepository _repository;

  DateTime visibleMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );
  int selectedDay = DateTime.now().day;
  List<WorkoutSession> daySessions = const [];
  bool loadingSessions = true;
  String? sessionLoadError;
  Set<int> activeDays = const {};

  String get selectedDateText {
    final month = visibleMonth.month.toString().padLeft(2, '0');
    final day = selectedDay.toString().padLeft(2, '0');
    return '${visibleMonth.year}-$month-$day';
  }

  Future<void> moveMonth(int delta) async {
    visibleMonth = DateTime(visibleMonth.year, visibleMonth.month + delta);
    final lastDay = DateUtils.getDaysInMonth(
      visibleMonth.year,
      visibleMonth.month,
    );
    selectedDay = selectedDay.clamp(1, lastDay);
    activeDays = const {};
    notifyListeners();
    await Future.wait([
      loadSelectedDaySessions(),
      loadVisibleMonthActiveDays(),
    ]);
  }

  Future<void> selectDay(int day) {
    selectedDay = day;
    notifyListeners();
    return loadSelectedDaySessions();
  }

  Future<void> loadSelectedDaySessions() {
    return loadSessionsByDate(selectedDateText);
  }

  Future<void> loadVisibleMonthActiveDays() async {
    final monthKey =
        '${visibleMonth.year}-${visibleMonth.month.toString().padLeft(2, '0')}';
    final targetYear = visibleMonth.year;
    final targetMonth = visibleMonth.month;
    try {
      final sessions = await _repository.getSessionsByMonth(monthKey);
      if (visibleMonth.year != targetYear ||
          visibleMonth.month != targetMonth) {
        return;
      }
      activeDays = sessions
          .where(
            (s) =>
                s.startedAt.year == targetYear &&
                s.startedAt.month == targetMonth,
          )
          .map((s) => s.startedAt.day)
          .toSet();
    } catch (_) {
      activeDays = const {};
    } finally {
      notifyListeners();
    }
  }

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

  Future<WorkoutSession> loadSessionDetail(String sessionId) {
    if (sessionId.isEmpty) {
      throw StateError('missing session id');
    }
    return _repository.getSessionDetail(sessionId);
  }
}
