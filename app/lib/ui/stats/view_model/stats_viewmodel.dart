import 'package:flutter/foundation.dart';

import '../../../data/repositories/stats_repository.dart';
import '../../../data/repositories/user_profile_repository.dart';
import '../widgets/stats_tab_bar.dart';
import '../widgets/svg_body_heatmap_view.dart';

class StatsViewModel extends ChangeNotifier {
  StatsViewModel(this._repository, this._profileRepository);

  final StatsRepository _repository;
  final UserProfileRepository _profileRepository;

  int weekOffset = 0;
  bool loading = true;
  String? loadError;
  Map<String, dynamic>? weeklyStats;
  Map<String, dynamic>? heatmap;
  Map<String, dynamic>? balance;
  StatsTab selectedTab = StatsTab.heatmap;
  BodyGender gender = BodyGender.male;

  DateTime get weekStart {
    final today = DateTime.now();
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final target = monday.add(Duration(days: weekOffset * 7));
    return DateTime(target.year, target.month, target.day);
  }

  String get weekStartText {
    final start = weekStart;
    final month = start.month.toString().padLeft(2, '0');
    final day = start.day.toString().padLeft(2, '0');
    return '${start.year}-$month-$day';
  }

  Future<void> moveWeek(int delta) {
    weekOffset += delta;
    notifyListeners();
    return loadSelectedWeekStats();
  }

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
      // 캐시된 프로필 사용 — getProfile()은 캐시 히트 시 즉시 반환
      final profile = await _profileRepository.getProfile();
      gender = bodyGenderFromCode(profile.gender);
      loading = false;
    } catch (_) {
      loading = false;
      loadError = '통계 정보를 불러오지 못했습니다.';
    } finally {
      notifyListeners();
    }
  }

  Future<void> loadSelectedWeekStats() {
    return loadStats(weekStartText);
  }

  void selectTab(StatsTab tab) {
    selectedTab = tab;
    notifyListeners();
  }
}
