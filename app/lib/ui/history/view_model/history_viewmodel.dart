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

  String get selectedDateText {
    final month = visibleMonth.month.toString().padLeft(2, '0');
    final day = selectedDay.toString().padLeft(2, '0');
    return '${visibleMonth.year}-$month-$day';
  }

  Future<void> moveMonth(int delta) {
    visibleMonth = DateTime(visibleMonth.year, visibleMonth.month + delta);
    final lastDay = DateUtils.getDaysInMonth(
      visibleMonth.year,
      visibleMonth.month,
    );
    selectedDay = selectedDay.clamp(1, lastDay);
    notifyListeners();
    return loadSelectedDaySessions();
  }

  Future<void> selectDay(int day) {
    selectedDay = day;
    notifyListeners();
    return loadSelectedDaySessions();
  }

  Future<void> loadSelectedDaySessions() {
    return loadSessionsByDate(selectedDateText);
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
}
