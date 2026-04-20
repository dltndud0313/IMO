import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/session_record.dart';
import '../models/user_profile.dart';
import '../services/profile_storage.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../utils/nav.dart';
import '../widgets/contribution_heatmap.dart';
import '../widgets/goal_achievement_dialog.dart';
import '../widgets/ui/gradient_button.dart';
import '../widgets/ui/progress_ring.dart';
import '../widgets/ui/section_card.dart';
import '../widgets/ui/skeleton.dart';
import 'history_screen.dart';
import 'mode_select_screen.dart';
import 'mypage_screen.dart';
import 'routine/routine_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseHelper();
  final _storage = ProfileStorage();
  final _settings = SettingsService();

  UserProfile? _profile;
  SessionRecord? _lastSession;
  int _streakDays = 0;
  int _weeklySessionCount = 0;
  int _weeklyTotalReps = 0;
  List<SessionRecord> _weekRecords = [];
  List<SessionRecord> _recentRecords = [];
  bool _loading = true;
  bool _goalCelebrated = false;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final heatmapStart = now.subtract(const Duration(days: 14 * 7));

    // 병렬 로드
    final results = await Future.wait([
      _storage.loadProfile(),
      _db.getLastSession(),
      _db.getStreakDays(),
      _db.getWeeklyStats(),
      _db.getSessionsAfter(monday),
      _db.getSessionsAfter(heatmapStart),
    ]);

    if (!mounted) return;
    setState(() {
      _profile = results[0] as UserProfile?;
      _lastSession = results[1] as SessionRecord?;
      _streakDays = results[2] as int;
      final weekly = results[3] as Map<String, dynamic>;
      _weeklySessionCount = weekly['sessionCount'] as int;
      _weeklyTotalReps = weekly['totalReps'] as int;
      _weekRecords = results[4] as List<SessionRecord>;
      _recentRecords = results[5] as List<SessionRecord>;
      _loading = false;
    });
    _checkGoalAchievement();
  }

  void _checkGoalAchievement() {
    if (_goalCelebrated) return;
    final sessionDone = _weeklySessionCount >= _settings.weeklySessionGoal;
    final repDone = _weeklyTotalReps >= _settings.weeklyRepGoal;
    if (sessionDone && repDone) {
      _goalCelebrated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        GoalAchievementDialog.show(
          context,
          message:
              '운동 $_weeklySessionCount회 · 반복 $_weeklyTotalReps회 달성!\n꾸준함이 멋져요 💪',
        );
      });
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return '좋은 아침이에요';
    if (hour < 18) return '좋은 오후예요';
    return '좋은 저녁이에요';
  }

  String get _motivation {
    if (_streakDays >= 7) return '🔥 일주일 연속 운동! 대단해요';
    if (_streakDays >= 3) return '💪 꾸준히 하고 있어요';
    if (_lastSession == null) return '첫 운동을 시작해보세요';
    return '오늘도 한 세트 어때요?';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const _HomeSkeleton()
            : RefreshIndicator(
                onRefresh: _loadDashboard,
                color: AppTheme.primary,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // ── 커스텀 헤더 ──
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTokens.space20,
                        AppTokens.space8,
                        AppTokens.space20,
                        AppTokens.space16,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: _HomeHeader(
                          onHistory: () => Nav.push(
                                  context, const HistoryScreen())
                              .then((_) => _loadDashboard()),
                          onMyPage: () =>
                              Nav.push(context, const MyPageScreen()),
                        ),
                      ),
                    ),
                    // ── 본문 ──
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTokens.space20,
                        0,
                        AppTokens.space20,
                        AppTokens.space32,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _HeroCard(
                            greeting: _greeting,
                            name: _profile?.name ?? '사용자',
                            motivation: _motivation,
                            streakDays: _streakDays,
                            sessionCount: _weeklySessionCount,
                            sessionGoal: _settings.weeklySessionGoal,
                            repCount: _weeklyTotalReps,
                            repGoal: _settings.weeklyRepGoal,
                          ),
                          const SizedBox(height: AppTokens.space16),
                          _StatRow(
                            weeklySessions: _weeklySessionCount,
                            weeklyReps: _weeklyTotalReps,
                            streak: _streakDays,
                          ),
                          const SizedBox(height: AppTokens.space16),
                          if (_weekRecords.isNotEmpty) ...[
                            _WeekMiniChart(records: _weekRecords),
                            const SizedBox(height: AppTokens.space16),
                          ],
                          SectionCard(
                            padding: const EdgeInsets.all(AppTokens.space16),
                            child: ContributionHeatmap(records: _recentRecords),
                          ),
                          const SizedBox(height: AppTokens.space16),
                          if (_lastSession != null) ...[
                            _LastSessionCard(session: _lastSession!),
                            const SizedBox(height: AppTokens.space20),
                          ],
                          GradientButton(
                            label: '운동 시작하기',
                            icon: Icons.play_arrow_rounded,
                            gradient: AppGradients.action,
                            onPressed: () => Nav.push(
                                context, const ModeSelectScreen()),
                          ),
                          const SizedBox(height: AppTokens.space12),
                          OutlinedButton.icon(
                            onPressed: () => Nav.push(
                                context, const RoutineListScreen()),
                            icon: const Icon(Icons.list_alt_rounded),
                            label: const Text('루틴으로 시작'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(56),
                              foregroundColor: isDark
                                  ? AppTheme.textPrimaryDark
                                  : AppTheme.textPrimary,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ─────────── Sub Widgets ───────────

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onHistory, required this.onMyPage});

  final VoidCallback onHistory;
  final VoidCallback onMyPage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          'Inside Muscle Out',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const Spacer(),
        _CircleIconButton(icon: Icons.history_rounded, onTap: onHistory),
        const SizedBox(width: AppTokens.space8),
        _CircleIconButton(icon: Icons.person_outline_rounded, onTap: onMyPage),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? AppTheme.cardDark : AppTheme.card,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? AppTheme.borderDark : AppTheme.border,
            ),
          ),
          child: Icon(icon, size: 20),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.greeting,
    required this.name,
    required this.motivation,
    required this.streakDays,
    required this.sessionCount,
    required this.sessionGoal,
    required this.repCount,
    required this.repGoal,
  });

  final String greeting;
  final String name;
  final String motivation;
  final int streakDays;
  final int sessionCount;
  final int sessionGoal;
  final int repCount;
  final int repGoal;

  @override
  Widget build(BuildContext context) {
    final sessionPct = sessionGoal == 0 ? 0.0 : sessionCount / sessionGoal;
    final repPct = repGoal == 0 ? 0.0 : repCount / repGoal;

    return Container(
      padding: const EdgeInsets.all(AppTokens.space24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A237E), Color(0xFF3B5BDB), Color(0xFF4DA8FF)],
          stops: [0.0, 0.6, 1.0],
        ),
        boxShadow: AppTokens.shadowGlow(const Color(0xFF3B5BDB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$name님 👋',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (streakDays > 0) _StreakBadge(days: streakDays),
            ],
          ),
          const SizedBox(height: AppTokens.space20),
          Row(
            children: [
              // 2-링 프로그레스
              ProgressRing(
                size: 124,
                strokeWidth: 10,
                trackColor: Colors.white.withValues(alpha: 0.18),
                rings: [
                  RingData(progress: repPct, color: AppGradients.ringExercise),
                  RingData(progress: sessionPct, color: AppGradients.ringMove),
                ],
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$sessionCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '/ $sessionGoal 세션',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTokens.space20),
              // 목표 범례
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _GoalLegend(
                      color: AppGradients.ringMove,
                      label: '세션',
                      value: '$sessionCount / $sessionGoal',
                    ),
                    const SizedBox(height: AppTokens.space12),
                    _GoalLegend(
                      color: AppGradients.ringExercise,
                      label: '반복',
                      value: '$repCount / $repGoal',
                    ),
                    const SizedBox(height: AppTokens.space12),
                    Text(
                      motivation,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            '$days일 연속',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalLegend extends StatelessWidget {
  const _GoalLegend({
    required this.color,
    required this.label,
    required this.value,
  });
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.weeklySessions,
    required this.weeklyReps,
    required this.streak,
  });

  final int weeklySessions;
  final int weeklyReps;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: '$weeklySessions',
            unit: '회',
            label: '이번 주 세션',
            icon: Icons.calendar_today_rounded,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: AppTokens.space12),
        Expanded(
          child: _StatCard(
            value: '$weeklyReps',
            label: '총 반복',
            icon: Icons.repeat_rounded,
            color: AppTheme.rehab,
          ),
        ),
        const SizedBox(width: AppTokens.space12),
        Expanded(
          child: _StatCard(
            value: '$streak',
            unit: '일',
            label: '연속',
            icon: Icons.local_fire_department_rounded,
            color: AppTheme.accent,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.unit,
  });

  final String value;
  final String? unit;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return SectionCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space12,
        vertical: AppTokens.space16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: AppTokens.space12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  height: 1.0,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 2),
                Text(
                  unit!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _LastSessionCard extends StatelessWidget {
  const _LastSessionCard({required this.session});
  final SessionRecord session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subColor =
        isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary;

    return SectionCard(
      padding: const EdgeInsets.all(AppTokens.space16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: AppGradients.primary,
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              boxShadow: AppTokens.shadowGlow(AppTheme.primary),
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: AppTokens.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '마지막 운동',
                  style: TextStyle(
                    fontSize: 11,
                    color: subColor,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  session.exerciseName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  session.formattedDateTime,
                  style: TextStyle(fontSize: 12, color: subColor),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${session.totalReps}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                  letterSpacing: -0.5,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '보상 ${session.compensationCount}',
                style: TextStyle(fontSize: 11, color: subColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekMiniChart extends StatelessWidget {
  const _WeekMiniChart({required this.records});
  final List<SessionRecord> records;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final now = DateTime.now();
    final labels = <String>[];
    final repsData = <double>[];

    for (var i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      labels.add('${d.month}/${d.day}');
      int dayReps = 0;
      for (final r in records) {
        if (r.date.year == d.year &&
            r.date.month == d.month &&
            r.date.day == d.day) {
          dayReps += r.totalReps;
        }
      }
      repsData.add(dayReps.toDouble());
    }

    final maxY =
        repsData.fold<double>(0, (a, b) => a > b ? a : b).clamp(10, 9999);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '이번 주 운동 추이',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${repsData.fold<double>(0, (a, b) => a + b).toInt()}회',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppTheme.textSecondaryDark
                      : AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space16),
          SizedBox(
            height: 130,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY.toDouble(),
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      getTitlesWidget: (value, _) {
                        final i = value.toInt();
                        if (i < 0 || i >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            labels[i],
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? AppTheme.textSecondaryDark
                                  : AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(7, (i) {
                  final hasData = repsData[i] > 0;
                  return BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: repsData[i],
                      gradient: hasData ? AppGradients.primary : null,
                      color: hasData
                          ? null
                          : (isDark
                              ? AppTheme.borderDark
                              : AppTheme.border),
                      width: 18,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ]);
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTokens.space20),
      children: const [
        SkeletonCard(height: 220),
        SizedBox(height: AppTokens.space16),
        Row(
          children: [
            Expanded(child: SkeletonCard(height: 100)),
            SizedBox(width: AppTokens.space12),
            Expanded(child: SkeletonCard(height: 100)),
            SizedBox(width: AppTokens.space12),
            Expanded(child: SkeletonCard(height: 100)),
          ],
        ),
        SizedBox(height: AppTokens.space16),
        SkeletonCard(height: 180),
        SizedBox(height: AppTokens.space16),
        SkeletonCard(height: 140),
        SizedBox(height: AppTokens.space16),
        SkeletonCard(height: 80),
      ],
    );
  }
}
