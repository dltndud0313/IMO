import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/session_record.dart';
import '../theme/app_theme.dart';

/// 특정 운동 종목의 상세 통계.
class ExerciseStatsScreen extends StatefulWidget {
  final String exerciseName;
  const ExerciseStatsScreen({super.key, required this.exerciseName});

  @override
  State<ExerciseStatsScreen> createState() => _ExerciseStatsScreenState();
}

class _ExerciseStatsScreenState extends State<ExerciseStatsScreen> {
  final _db = DatabaseHelper();
  List<SessionRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await _db.getSessionsByExercise(widget.exerciseName);
    if (!mounted) return;
    setState(() {
      _records = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.exerciseName)),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _records.isEmpty
                ? const Center(
                    child: Text('아직 기록이 없어요',
                        style: TextStyle(color: AppTheme.textSecondary)),
                  )
                : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final totalSessions = _records.length;
    final totalReps =
        _records.fold<int>(0, (a, b) => a + b.totalReps);
    final totalComp =
        _records.fold<int>(0, (a, b) => a + b.compensationCount);
    final bestReps = _records
        .map((r) => r.totalReps)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final avgReps = totalSessions == 0 ? 0 : (totalReps / totalSessions);
    final compRate =
        totalReps == 0 ? 0.0 : (totalComp / totalReps).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SummaryGrid(
          items: [
            _SummaryItem(label: '총 세션', value: '$totalSessions'),
            _SummaryItem(label: '총 반복', value: '$totalReps'),
            _SummaryItem(label: '최고 반복', value: '$bestReps'),
            _SummaryItem(
                label: '평균 반복', value: avgReps.toStringAsFixed(1)),
          ],
        ),
        const SizedBox(height: 16),

        // 보상동작 비율
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('보상동작 비율',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: compRate,
                  minHeight: 10,
                  backgroundColor: AppTheme.border,
                  valueColor: AlwaysStoppedAnimation(
                      compRate > 0.3 ? AppTheme.accent : AppTheme.success),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(compRate * 100).toStringAsFixed(1)}% '
                  '($totalComp / $totalReps)',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 반복수 추이
        if (_records.length >= 2) ...[
          _TrendChart(records: _records),
          const SizedBox(height: 16),
        ],

        // 전체 세션 목록
        const Text('세션 기록',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ..._records.map((r) => Card(
              child: ListTile(
                title: Text(
                  '${r.totalReps}회',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(r.formattedDateTime),
                trailing: Text(
                  '보상 ${r.compensationCount}',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            )),
      ],
    );
  }
}

class _SummaryItem {
  final String label;
  final String value;
  const _SummaryItem({required this.label, required this.value});
}

class _SummaryGrid extends StatelessWidget {
  final List<_SummaryItem> items;
  const _SummaryGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: items
          .map((i) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        i.label,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        i.value,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<SessionRecord> records;
  const _TrendChart({required this.records});

  @override
  Widget build(BuildContext context) {
    // 오래된 → 최신 순서로 재정렬 (records는 DESC)
    final asc = records.reversed.toList();
    final maxReps = asc
        .map((r) => r.totalReps)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final maxY = (maxReps + 5).toDouble().clamp(10.0, 9999.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('반복수 추이',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
                          if (i < 0 || i >= asc.length) {
                            return const SizedBox.shrink();
                          }
                          // 최대 6개 라벨만 표시
                          final step = (asc.length / 6).ceil().clamp(1, 9999);
                          if (i % step != 0) return const SizedBox.shrink();
                          return Text(
                            '${asc[i].date.month}/${asc[i].date.day}',
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
                      spots: List.generate(asc.length, (i) {
                        return FlSpot(
                            i.toDouble(), asc[i].totalReps.toDouble());
                      }),
                      color: AppTheme.primary,
                      barWidth: 2,
                      isCurved: true,
                      preventCurveOverShooting: true,
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.primary.withValues(alpha: 0.12),
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
