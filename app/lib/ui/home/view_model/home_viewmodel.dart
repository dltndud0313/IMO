import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/user_profile_repository.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel(this._profileRepo)
      : _greetingSubtitle =
            _greetings[Random().nextInt(_greetings.length)];

  final UserProfileRepository _profileRepo;
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
}
