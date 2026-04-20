import 'package:shared_preferences/shared_preferences.dart';

import '../db/database_helper.dart';
import '../models/pose_data.dart';
import '../models/user_profile.dart';

/// 프로필/포즈 데이터 SharedPreferences 저장소.
/// 유저별로 키를 분리하여 데이터 격리.
class ProfileStorage {
  static const _kLoggedIn = 'logged_in';
  static const _kEmail = 'user_email';

  /// 유저별 키 생성
  String _userKey(String key, String email) => '${email}__$key';

  Future<void> setLoggedIn(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLoggedIn, true);
    await prefs.setString(_kEmail, email);
    // DB에도 현재 유저 세팅
    DatabaseHelper().currentUserEmail = email;
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool(_kLoggedIn) ?? false;
    if (loggedIn) {
      // DB에 현재 유저 세팅
      final email = prefs.getString(_kEmail);
      if (email != null) {
        DatabaseHelper().currentUserEmail = email;
      }
    }
    return loggedIn;
  }

  Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kEmail);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLoggedIn);
    // 이메일은 유지 (다음 로그인 시 참조)
    DatabaseHelper().currentUserEmail = null;
  }

  Future<void> saveProfile(UserProfile profile) async {
    final email = await getEmail();
    if (email == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey('profile', email), profile.encode());
  }

  Future<UserProfile?> loadProfile() async {
    final email = await getEmail();
    if (email == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_userKey('profile', email));
    if (s == null) return null;
    return UserProfile.decode(s);
  }

  Future<void> savePose(PoseData pose) async {
    final email = await getEmail();
    if (email == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey('pose', email), pose.encode());
  }

  Future<PoseData?> loadPose() async {
    final email = await getEmail();
    if (email == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_userKey('pose', email));
    if (s == null) return null;
    return PoseData.decode(s);
  }

  Future<bool> hasOnboarded() async {
    final p = await loadProfile();
    final pose = await loadPose();
    return p != null && pose != null;
  }

  Future<void> clear() async {
    final email = await getEmail();
    if (email == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey('profile', email));
    await prefs.remove(_userKey('pose', email));
  }
}
