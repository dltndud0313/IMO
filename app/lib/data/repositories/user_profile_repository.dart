import 'dart:async';

import '../../domain/models/user_profile.dart';
import '../services/api_service.dart';

/// 사용자 프로필 관리 Repository
class UserProfileRepository {
  final ApiService _api;
  UserProfile? _cachedProfile;
  final _profileChanges = StreamController<UserProfile>.broadcast();

  UserProfileRepository(this._api);

  Stream<UserProfile> get profileChanges => _profileChanges.stream;

  Future<UserProfile> getProfile({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedProfile != null) return _cachedProfile!;
    _cachedProfile = await _api.getProfile();
    return _cachedProfile!;
  }

  Future<void> updateProfile(UserProfile profile) async {
    final updated = await _api.updateProfile(profile);
    _cachedProfile = updated;
    _profileChanges.add(updated);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _api.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  void clearCache() {
    _cachedProfile = null;
  }
}
