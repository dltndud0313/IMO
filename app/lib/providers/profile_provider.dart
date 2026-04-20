import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import '../services/profile_storage.dart';

/// ProfileStorage 싱글 인스턴스 제공.
final profileStorageProvider = Provider((_) => ProfileStorage());

/// 현재 로그인된 사용자 프로필.
/// invalidate 호출 시 다시 로드.
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final storage = ref.read(profileStorageProvider);
  return storage.loadProfile();
});

/// 현재 로그인 이메일.
final userEmailProvider = FutureProvider<String?>((ref) async {
  final storage = ref.read(profileStorageProvider);
  return storage.getEmail();
});
