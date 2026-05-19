import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/session_history_repository.dart';
import '../../../data/repositories/user_profile_repository.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel(this._profileRepo, this._sessionRepo)
      : _greetingSubtitle =
            _greetings[Random().nextInt(_greetings.length)];

  final UserProfileRepository _profileRepo;
  final SessionHistoryRepository _sessionRepo;
  final String _greetingSubtitle;

  static const _greetings = [
    '꾸준함이 결국 답입니다',
    '오늘의 1%가 큰 차이를 만듭니다',
    '어제보다 더 강한 나',
    '한 번 더, 한 세트 더',
    '운동은 자신에게 주는 선물입니다',
    '멈추지 않으면 늦지 않습니다',
    '땀은 거짓말하지 않습니다',
    '오늘도 한 걸음 더 나아갑니다',
    '시작이 반, 꾸준함이 전부',
    '쉬운 길은 결과를 만들지 않습니다',
  ];

  String get greetingSubtitle => _greetingSubtitle;

  String? _nickname;
  String? get nickname => _nickname;

  bool _isLoadingProfile = false;
  bool get isLoadingProfile => _isLoadingProfile;

  int _todaySessionCount = 0;
  int get todaySessionCount => _todaySessionCount;

  int _todayTotalReps = 0;
  int get todayTotalReps => _todayTotalReps;

  int _todayDurationMin = 0;
  int get todayDurationMin => _todayDurationMin;

  bool _isLoadingTodaySummary = false;
  bool get isLoadingTodaySummary => _isLoadingTodaySummary;

  Future<void> loadProfile() async {
    if (_isLoadingProfile) return;
    _isLoadingProfile = true;
    notifyListeners();

    try {
      final profile = await _profileRepo.getProfile();
      _nickname = profile.nickname;
    } catch (_) {
      // 닉네임은 화면에서 fallback("사용자")으로 노출되므로 silent failure
    } finally {
      _isLoadingProfile = false;
      notifyListeners();
    }
  }

  Future<void> loadTodaySummary() async {
    if (_isLoadingTodaySummary) return;
    _isLoadingTodaySummary = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      final today =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final sessions = await _sessionRepo.getSessionsByDate(today);

      _todaySessionCount = sessions.length;
      _todayTotalReps =
          sessions.fold<int>(0, (sum, s) => sum + s.totalReps);
      final totalSec =
          sessions.fold<int>(0, (sum, s) => sum + s.durationSec);
      _todayDurationMin = totalSec ~/ 60;
    } catch (_) {
      // 카드는 0으로 fallback. 시연 중 백엔드 실패 시에도 무한 로딩 방지
    } finally {
      _isLoadingTodaySummary = false;
      notifyListeners();
    }
  }
}
