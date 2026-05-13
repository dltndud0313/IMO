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
  bool loading = false;
  String? loadError;
  Map<String, dynamic>? weeklyStats;
  Map<String, dynamic>? heatmap;
  Map<String, dynamic>? balance;
  StatsTab selectedTab = StatsTab.heatmap;
  BodyGender gender = BodyGender.male;

  bool get hasData =>
      heatmap != null || balance != null || weeklyStats != null;

  DateTime get weekStart {
    final today = DateTime.now();
    final sunday = today.subtract(Duration(days: today.weekday % 7));
    final target = sunday.add(Duration(days: weekOffset * 7));
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
      // 4개 호출을 동시에 시작 — 직렬로 await해도 모두 병렬로 실행됨
      final statsFuture = _repository.getWeeklyStats(weekStart);
      final heatmapFuture = _repository.getWeeklyHeatmap(weekStart);
      final balanceFuture = _repository.getWeeklyBalance(weekStart);
      final profileFuture = _profileRepository.getProfile();

      weeklyStats = await statsFuture;
      heatmap = await heatmapFuture;
      balance = await balanceFuture;
      gender = bodyGenderFromCode((await profileFuture).gender);
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
