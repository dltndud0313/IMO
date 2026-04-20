import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/session_record.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../utils/nav.dart';
import '../widgets/calendar_widget.dart';
import '../widgets/ui/section_card.dart';
import '../widgets/ui/skeleton.dart';
import 'exercise_stats_screen.dart';
import 'history_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _db = DatabaseHelper();

  // 주간
  List<SessionRecord> _allRecords = [];
  bool _loading = true;

  // 월간
  int _calYear = DateTime.now().year;
  int _calMonth = DateTime.now().month;
  List<SessionRecord> _monthRecords = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        if (_tabCtrl.index == 1) _loadMonth();
      }
    });
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final rows = await _db.getAllSessions();
    if (!mounted) return;
    setState(() {
      _allRecords = rows;
      _loading = false;
    });
    _loadMonth();
  }

  Future<void> _loadMonth() async {
    final rows = await _db.getSessionsByMonth(_calYear, _calMonth);
    if (!mounted) return;
    setState(() => _monthRecords = rows);
  }

  // ─── 주간 데이터 ───

  Map<String, _DayStat> _weeklyStats() {
    final now = DateTime.now();
    final stats = <String, _DayStat>{};
    for (var i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key = '${d.month}/${d.day}';
      stats[key] = _DayStat(0, 0);
    }
    for (final r in _allRecords) {
      final diff = now.difference(r.date).inDays;
      if (diff < 0 || diff > 6) continue;
      final key = '${r.date.month}/${r.date.day}';
      final prev = stats[key] ?? _DayStat(0, 0);
      stats[key] = _DayStat(
        prev.reps + r.totalReps,
        prev.comp + r.compensationCount,
      );
    }
    return stats;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('운동 기록'),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(text: '주간'),
            Tab(text: '월간'),
            Tab(text: '전체'),
          ],
        ),
      ),
      body: SafeArea(
        child: _loading
            ? ListView(
                padding: const EdgeInsets.all(AppTokens.space20),
                children: const [
                  SkeletonCard(height: 200),
                  SizedBox(height: AppTokens.space16),
                  SkeletonCard(height: 80),
                  SizedBox(height: AppTokens.space12),
                  SkeletonCard(height: 80),
                  SizedBox(height: AppTokens.space12),
                  SkeletonCard(height: 80),
                ],
              )
            : TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildWeeklyTab(),
                  _buildMonthlyTab(),
                  _buildAllTab(),
                ],
              ),
      ),
    );
  }

  // ─── 주간 탭 ───

  Widget _buildWeeklyTab() {
    if (_allRecords.isEmpty) return _emptyWidget();
    final stats = _weeklyStats();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _WeeklyChart(stats: stats),
        const SizedBox(height: 20),
        const Text('최근 기록',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ..._allRecords.take(10).map((r) => _SessionTile(
              record: r,
              onTap: () => _openDetail(r),
            )),
      ],
    );
  }

  // ─── 월간 탭 ───

  Widget _buildMonthlyTab() {
    final activeDays = <int>{};
    int totalReps = 0;
    int totalComp = 0;
    for (final r in _monthRecords) {
      activeDays.add(r.date.day);
      totalReps += r.totalReps;
      totalComp += r.compensationCount;
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        CalendarWidget(
          year: _calYear,
          month: _calMonth,
          activeDays: activeDays,
          onPrevMonth: () {
            setState(() {
              if (_calMonth == 1) {
                _calMonth = 12;
                _calYear--;
              } else {
                _calMonth--;
              }
            });
            _loadMonth();
          },
          onNextMonth: () {
            setState(() {
              if (_calMonth == 12) {
                _calMonth = 1;
                _calYear++;
              } else {
                _calMonth++;
              }
            });
            _loadMonth();
          },
          onDayTap: (date) {
            // 해당 날짜 세션 필터
            final daySessions = _monthRecords
                .where((r) =>
                    r.date.year == date.year &&
                    r.date.month == date.month &&
                    r.date.day == date.day)
                .toList();
            if (daySessions.isEmpty) return;
            showModalBottomSheet(
              context: context,
              builder: (_) => _DaySessionSheet(sessions: daySessions),
            );
          },
        ),
        const SizedBox(height: 16),
        // 월간 요약
        SectionCard(
          padding: const EdgeInsets.all(AppTokens.space20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MiniStat(
                  label: '운동 횟수',
                  value: '${_monthRecords.length}',
                  unit: '회',
                  color: AppTheme.primary),
              _MiniStat(
                  label: '총 반복',
                  value: '$totalReps',
                  color: AppTheme.rehab),
              _MiniStat(
                  label: '보상동작',
                  value: '$totalComp',
                  color: AppTheme.accent),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ..._monthRecords.map((r) => _SessionTile(
              record: r,
              onTap: () => _openDetail(r),
            )),
      ],
    );
  }

  // ─── 전체 탭 ───

  Widget _buildAllTab() {
    if (_allRecords.isEmpty) return _emptyWidget();

    // 종목별 집계
    final byExercise = <String, _ExerciseAgg>{};
    for (final r in _allRecords) {
      final agg = byExercise[r.exerciseName] ?? _ExerciseAgg(0, 0, 0);
      byExercise[r.exerciseName] = _ExerciseAgg(
        agg.sessions + 1,
        agg.reps + r.totalReps,
        agg.best > r.totalReps ? agg.best : r.totalReps,
      );
    }
    final exerciseEntries = byExercise.entries.toList()
      ..sort((a, b) => b.value.sessions.compareTo(a.value.sessions));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // 운동별 진행 추이
        if (_allRecords.length >= 2) ...[
          _ProgressChart(records: _allRecords),
          const SizedBox(height: 16),
        ],

        // 종목별 통계 진입
        const Text('종목별 통계',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ...exerciseEntries.map((e) => Card(
              child: ListTile(
                leading: const Icon(Icons.insights,
                    color: AppTheme.primary),
                title: Text(e.key,
                    style:
                        const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  '${e.value.sessions}세션 · 총 ${e.value.reps}회 · 최고 ${e.value.best}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right,
                    color: AppTheme.textSecondary),
                onTap: () => Nav.push(
                    context, ExerciseStatsScreen(exerciseName: e.key)),
              ),
            )),
        const SizedBox(height: 16),
        const Text('전체 기록',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ..._allRecords.map((r) => _SessionTile(
              record: r,
              onTap: () => _openDetail(r),
            )),
      ],
    );
  }

  Widget _emptyWidget() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subColor =
        isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark : AppTheme.card,
              shape: BoxShape.circle,
              boxShadow: AppTokens.shadowSoft(),
            ),
            child: Icon(
              Icons.history_rounded,
              size: 40,
              color: subColor,
            ),
          ),
          const SizedBox(height: AppTokens.space20),
          const Text(
            '아직 운동 기록이 없어요',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppTokens.space4),
          Text(
            '첫 운동을 시작해 기록을 만들어보세요',
            style: TextStyle(fontSize: 13, color: subColor),
          ),
        ],
      ),
    );
  }

  void _openDetail(SessionRecord r) async {
    final deleted = await Nav.push<bool>(
        context, HistoryDetailScreen(record: r));
    if (deleted == true) _load();
  }
}

// ─── 서브 위젯 ───

class _DayStat {
  final int reps;
  final int comp;
  const _DayStat(this.reps, this.comp);
}

class _ExerciseAgg {
  final int sessions;
  final int reps;
  final int best;
  const _ExerciseAgg(this.sessions, this.reps, this.best);
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final Color color;
  const _MiniStat({
    required this.label,
    required this.value,
    this.unit,
    this.color = AppTheme.primary,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 2),
              Text(
                unit!,
                style: TextStyle(
                  fontSize: 12,
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
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isDark
                ? AppTheme.textSecondaryDark
                : AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SessionTile extends StatelessWidget {
  final SessionRecord record;
  final VoidCallback onTap;
  const _SessionTile({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subColor =
        isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.space12),
      child: SectionCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppTokens.space16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              ),
              child: const Icon(
                Icons.fitness_center_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: AppTokens.space16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.exerciseName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    record.formattedDate,
                    style: TextStyle(fontSize: 12, color: subColor),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${record.totalReps}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                    letterSpacing: -0.5,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '보상 ${record.compensationCount}',
                  style: TextStyle(fontSize: 11, color: subColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DaySessionSheet extends StatelessWidget {
  final List<SessionRecord> sessions;
  const _DaySessionSheet({required this.sessions});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sessions.first.formattedDate,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ...sessions.map((s) => ListTile(
                leading:
                    const Icon(Icons.fitness_center, color: AppTheme.primary),
                title: Text(s.exerciseName),
                subtitle: Text('${s.totalReps}회 · 보상 ${s.compensationCount}'),
                trailing: Text(
                  '${s.date.hour.toString().padLeft(2, '0')}:${s.date.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              )),
        ],
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  final Map<String, _DayStat> stats;
  const _WeeklyChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final labels = stats.keys.toList();
    final maxReps = stats.values
        .map((s) => s.reps)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final double maxY = (maxReps + 5).toDouble().clamp(10.0, 9999.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('이번 주 운동 추이',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(width: 12, height: 3, color: AppTheme.primary),
                const SizedBox(width: 4),
                const Text('반복수', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 12),
                Container(width: 12, height: 3, color: AppTheme.accent),
                const SizedBox(width: 4),
                const Text('보상동작', style: TextStyle(fontSize: 11)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval:
                        (maxY / 4).ceilToDouble().clamp(1.0, 9999.0),
                  ),
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
                        getTitlesWidget: (value, _) {
                          final i = value.toInt();
                          if (i < 0 || i >= labels.length) {
                            return const SizedBox.shrink();
                          }
                          return Text(labels[i],
                              style: const TextStyle(fontSize: 10));
                        },
                        interval: 1,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(labels.length, (i) {
                        return FlSpot(
                            i.toDouble(),
                            stats[labels[i]]!.reps.toDouble());
                      }),
                      color: AppTheme.primary,
                      barWidth: 2,
                      dotData: const FlDotData(show: true),
                      isCurved: true,
                      preventCurveOverShooting: true,
                    ),
                    LineChartBarData(
                      spots: List.generate(labels.length, (i) {
                        return FlSpot(
                            i.toDouble(),
                            stats[labels[i]]!.comp.toDouble());
                      }),
                      color: AppTheme.accent,
                      barWidth: 2,
                      dotData: const FlDotData(show: true),
                      isCurved: true,
                      preventCurveOverShooting: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressChart extends StatelessWidget {
  final List<SessionRecord> records;
  const _ProgressChart({required this.records});

  @override
  Widget build(BuildContext context) {
    // 최근 10개 세션의 반복수 추이
    final recent = records.take(10).toList().reversed.toList();
    final maxReps = recent
        .map((r) => r.totalReps)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final maxY = (maxReps + 5).toDouble().clamp(10.0, 9999.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('반복수 추이 (최근 10회)',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY,
                  gridData: const FlGridData(
                      show: true, drawVerticalLine: false),
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
                        getTitlesWidget: (value, _) {
                          final i = value.toInt();
                          if (i < 0 || i >= recent.length) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            '${recent[i].date.month}/${recent[i].date.day}',
                            style: const TextStyle(fontSize: 9),
                          );
                        },
                        interval: 1,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(recent.length, (i) {
                        return FlSpot(
                            i.toDouble(), recent[i].totalReps.toDouble());
                      }),
                      color: AppTheme.primary,
                      barWidth: 2,
                      isCurved: true,
                      preventCurveOverShooting: true,
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.primary.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
