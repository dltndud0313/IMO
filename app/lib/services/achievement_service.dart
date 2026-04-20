import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/database_helper.dart';
import '../models/achievement.dart';
import '../theme/app_theme.dart';

/// 뱃지/성취 체크 및 저장 서비스.
class AchievementService {
  static final AchievementService _instance = AchievementService._();
  AchievementService._();
  factory AchievementService() => _instance;

  /// 전체 뱃지 정의
  static const List<Achievement> all = [
    Achievement(
      id: 'first_session',
      name: '첫 걸음',
      description: '첫 운동 세션을 완료하세요',
      icon: Icons.flag,
      color: AppTheme.primary,
    ),
    Achievement(
      id: 'reps_100',
      name: '백의 자리',
      description: '누적 반복 100회 달성',
      icon: Icons.repeat,
      color: AppTheme.primary,
    ),
    Achievement(
      id: 'reps_500',
      name: '꾸준함의 힘',
      description: '누적 반복 500회 달성',
      icon: Icons.trending_up,
      color: AppTheme.rehab,
    ),
    Achievement(
      id: 'reps_1000',
      name: '천 번의 반복',
      description: '누적 반복 1000회 달성',
      icon: Icons.emoji_events,
      color: AppTheme.warning,
    ),
    Achievement(
      id: 'streak_3',
      name: '3일 연속',
      description: '3일 연속 운동',
      icon: Icons.local_fire_department,
      color: AppTheme.accent,
    ),
    Achievement(
      id: 'streak_7',
      name: '일주일 연속',
      description: '7일 연속 운동',
      icon: Icons.local_fire_department,
      color: AppTheme.warning,
    ),
    Achievement(
      id: 'streak_30',
      name: '한 달 개근',
      description: '30일 연속 운동',
      icon: Icons.whatshot,
      color: AppTheme.accent,
    ),
    Achievement(
      id: 'perfect_set',
      name: '완벽한 세트',
      description: '보상동작 0회로 세션 완료 (10회 이상)',
      icon: Icons.verified,
      color: AppTheme.success,
    ),
    Achievement(
      id: 'sessions_10',
      name: '루틴 메이커',
      description: '운동 세션 10회 완료',
      icon: Icons.check_circle,
      color: AppTheme.primary,
    ),
    Achievement(
      id: 'sessions_50',
      name: '헬스 루틴',
      description: '운동 세션 50회 완료',
      icon: Icons.military_tech,
      color: AppTheme.warning,
    ),
  ];

  static Achievement byId(String id) =>
      all.firstWhere((a) => a.id == id, orElse: () => all.first);

  String _userKey(String email) => '${email}__unlocked_achievements';

  Future<String?> _email() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_email');
  }

  /// 해금된 뱃지 ID 집합
  Future<Set<String>> getUnlocked() async {
    final email = await _email();
    if (email == null) return {};
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_userKey(email)) ?? []).toSet();
  }

  Future<void> _setUnlocked(Set<String> ids) async {
    final email = await _email();
    if (email == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_userKey(email), ids.toList());
  }

  /// 세션 저장 후 호출. 새로 해금된 뱃지 목록을 반환.
  Future<List<Achievement>> checkAfterSession() async {
    final unlocked = await getUnlocked();
    final newly = <Achievement>[];

    final db = DatabaseHelper();
    final sessions = await db.getAllSessions();
    if (sessions.isEmpty) return [];

    final totalReps =
        sessions.fold<int>(0, (sum, s) => sum + s.totalReps);
    final streak = await db.getStreakDays();

    void tryUnlock(String id) {
      if (!unlocked.contains(id)) {
        unlocked.add(id);
        newly.add(byId(id));
      }
    }

    if (sessions.isNotEmpty) tryUnlock('first_session');
    if (totalReps >= 100) tryUnlock('reps_100');
    if (totalReps >= 500) tryUnlock('reps_500');
    if (totalReps >= 1000) tryUnlock('reps_1000');
    if (streak >= 3) tryUnlock('streak_3');
    if (streak >= 7) tryUnlock('streak_7');
    if (streak >= 30) tryUnlock('streak_30');
    if (sessions.length >= 10) tryUnlock('sessions_10');
    if (sessions.length >= 50) tryUnlock('sessions_50');

    // 마지막 세션이 보상동작 0 + 10회 이상이면 완벽한 세트
    final last = sessions.first;
    if (last.compensationCount == 0 && last.totalReps >= 10) {
      tryUnlock('perfect_set');
    }

    if (newly.isNotEmpty) await _setUnlocked(unlocked);
    return newly;
  }
}
