import 'package:flutter/foundation.dart';

import '../../../data/repositories/stats_repository.dart';

class StatsViewModel extends ChangeNotifier {
  StatsViewModel(this._repository);

  final StatsRepository _repository;

  bool loading = true;
  String? loadError;
  Map<String, dynamic>? weeklyStats;
  Map<String, dynamic>? heatmap;
  Map<String, dynamic>? balance;

  Future<void> loadStats(String weekStart) async {
    loading = true;
    loadError = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.getWeeklyStats(weekStart),
        _repository.getWeeklyHeatmap(weekStart),
        _repository.getWeeklyBalance(weekStart),
      ]);
      weeklyStats = results[0];
      heatmap = results[1];
      balance = results[2];
      loading = false;
    } catch (_) {
      loading = false;
      loadError = '통계 정보를 불러오지 못했습니다.';
    } finally {
      notifyListeners();
    }
  }
}
