import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/pose_data.dart';
import '../models/user_profile.dart';
import '../services/achievement_service.dart';
import '../services/profile_storage.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../utils/nav.dart';
import '../widgets/avatar_painter.dart';
import '../widgets/ui/section_card.dart';
import '../widgets/ui/skeleton.dart';
import 'achievements_screen.dart';
import 'avatar_test_screen.dart';
import 'profile_edit_screen.dart';
import 'settings_screen.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  final _storage = ProfileStorage();
  UserProfile? _profile;
  PoseData? _pose;
  String? _email;
  bool _loading = true;

  int _streakDays = 0;
  int _totalSessions = 0;
  int _totalReps = 0;
  int _achievementCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper();
    final results = await Future.wait([
      _storage.loadProfile(),
      _storage.loadPose(),
      _storage.getEmail(),
      db.getStreakDays(),
      db.getAllSessions(),
      AchievementService().getUnlocked(),
    ]);
    if (!mounted) return;
    final sessions = results[4] as List;
    final totalReps = sessions.fold<int>(
      0,
      (sum, s) => sum + ((s as dynamic).totalReps as int),
    );
    setState(() {
      _profile = results[0] as UserProfile?;
      _pose = results[1] as PoseData?;
      _email = results[2] as String?;
      _streakDays = results[3] as int;
      _totalSessions = sessions.length;
      _totalReps = totalReps;
      _achievementCount = (results[5] as Set).length;
      _loading = false;
    });
  }

  Future<void> _editProfile() async {
    if (_profile == null) return;
    final changed = await Nav.push<bool>(
      context,
      ProfileEditScreen(profile: _profile!),
    );
    if (changed == true) _load();
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        ),
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '로그아웃',
              style: TextStyle(color: AppTheme.danger),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _storage.logout();
    if (!mounted) return;
    Nav.toLogin(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('마이페이지'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '설정',
            onPressed: () => Nav.push(context, const SettingsScreen()),
          ),
          const SizedBox(width: AppTokens.space4),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? ListView(
                padding: const EdgeInsets.all(AppTokens.space20),
                children: const [
                  SkeletonCard(height: 180),
                  SizedBox(height: AppTokens.space16),
                  SkeletonCard(height: 260),
                  SizedBox(height: AppTokens.space16),
                  SkeletonCard(height: 72),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(AppTokens.space20),
                children: [
                  // ── 프로필 헤더 (그라데이션) ──
                  _ProfileHeader(
                    name: _profile?.name ?? '사용자',
                    email: _email ?? '',
                    pose: _pose,
                    streakDays: _streakDays,
                    totalSessions: _totalSessions,
                    totalReps: _totalReps,
                    achievementCount: _achievementCount,
                    onEdit: _editProfile,
                    onAvatarTap: () =>
                        Nav.push(context, const AvatarTestScreen()),
                  ),
                  const SizedBox(height: AppTokens.space16),

                  // ── 프로필 정보 ──
                  SectionCard(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTokens.space8,
                    ),
                    child: Column(
                      children: [
                        _InfoTile(
                          icon: Icons.height_rounded,
                          label: '키',
                          value: _profile != null
                              ? '${_profile!.heightCm.toStringAsFixed(0)} cm'
                              : '-',
                        ),
                        _divider(isDark),
                        _InfoTile(
                          icon: Icons.monitor_weight_outlined,
                          label: '체중',
                          value: _profile != null
                              ? '${_profile!.weightKg.toStringAsFixed(0)} kg'
                              : '-',
                        ),
                        _divider(isDark),
                        _InfoTile(
                          icon: Icons.cake_outlined,
                          label: '나이',
                          value:
                              _profile != null ? '${_profile!.age}세' : '-',
                        ),
                        _divider(isDark),
                        _InfoTile(
                          icon: Icons.wc_rounded,
                          label: '성별',
                          value: _profile?.gender == 'F'
                              ? '여성'
                              : _profile?.gender == 'M'
                                  ? '남성'
                                  : '-',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTokens.space16),

                  // ── 성취 진입 ──
                  SectionCard(
                    onTap: () =>
                        Nav.push(context, const AchievementsScreen()),
                    padding: const EdgeInsets.all(AppTokens.space16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: AppGradients.achievement,
                            borderRadius:
                                BorderRadius.circular(AppTokens.radiusMd),
                            boxShadow: AppTokens.shadowGlow(
                                const Color(0xFF8B5CF6)),
                          ),
                          child: const Icon(
                            Icons.emoji_events_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: AppTokens.space16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '업적 & 뱃지',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '달성한 성취를 확인해보세요',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: isDark
                              ? AppTheme.textSecondaryDark
                              : AppTheme.textSecondary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTokens.space32),

                  // ── 로그아웃 ──
                  OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded,
                        color: AppTheme.danger),
                    label: const Text(
                      '로그아웃',
                      style: TextStyle(
                        color: AppTheme.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      side: BorderSide(
                        color: AppTheme.danger.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _divider(bool isDark) => Divider(
        height: 1,
        indent: 56,
        endIndent: 16,
        color: isDark ? AppTheme.dividerDark : AppTheme.divider,
      );
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.pose,
    required this.streakDays,
    required this.totalSessions,
    required this.totalReps,
    required this.achievementCount,
    required this.onEdit,
    required this.onAvatarTap,
  });

  final String name;
  final String email;
  final PoseData? pose;
  final int streakDays;
  final int totalSessions;
  final int totalReps;
  final int achievementCount;
  final VoidCallback onEdit;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.space20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        gradient: AppGradients.primary,
        boxShadow: AppTokens.shadowGlow(AppTheme.primary),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // 아바타
              GestureDetector(
                onTap: onAvatarTap,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: pose == null
                      ? const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 48,
                        )
                      : ClipOval(
                          child: CustomPaint(
                            painter: AvatarPainter(pose: pose!),
                            child: const SizedBox.expand(),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: AppTokens.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (streakDays > 0) ...[
                      const SizedBox(height: 8),
                      _StreakBadge(days: streakDays),
                    ],
                    const SizedBox(height: AppTokens.space12),
                    Material(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius:
                          BorderRadius.circular(AppTokens.radiusPill),
                      child: InkWell(
                        onTap: onEdit,
                        borderRadius:
                            BorderRadius.circular(AppTokens.radiusPill),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_rounded,
                                  color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                '프로필 편집',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space16),
          // 빠른 통계 3개
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            ),
            child: Row(
              children: [
                _QuickStat(label: '세션', value: totalSessions.toString()),
                _QuickStat(label: '반복', value: totalReps.toString()),
                _QuickStat(label: '업적', value: achievementCount.toString()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            '$days일 연속',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  const _QuickStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space16,
        vertical: AppTokens.space12,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 18),
          ),
          const SizedBox(width: AppTokens.space12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
