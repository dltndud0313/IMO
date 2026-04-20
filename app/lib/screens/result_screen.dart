import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/exercise.dart';
import '../models/realtime_state.dart';
import '../models/session_record.dart';
import '../services/achievement_service.dart';
import '../theme/app_theme.dart';
import '../utils/nav.dart';
import '../widgets/achievement_unlock_dialog.dart';
import '../widgets/confetti_overlay.dart';

class ResultScreen extends StatefulWidget {
  final Exercise exercise;
  final SessionResult result;
  const ResultScreen({
    super.key,
    required this.exercise,
    required this.result,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  Exercise get exercise => widget.exercise;
  SessionResult get result => widget.result;
  bool _showConfetti = true;

  @override
  void initState() {
    super.initState();
    _saveSession();
  }

  Future<void> _saveSession() async {
    final record = SessionRecord(
      date: DateTime.now(),
      exerciseName: exercise.name,
      totalReps: result.totalReps,
      compensationCount: result.compensationCount,
      avgCh1: result.avgCh1,
      avgCh2: result.avgCh2,
      avgCh3: result.avgCh3,
      comment: result.comment,
    );
    await DatabaseHelper().insertSession(record);
    final newly = await AchievementService().checkAfterSession();
    if (newly.isNotEmpty && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AchievementUnlockDialog.showAll(context, newly);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('운동 결과'),
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 요약 카드
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        exercise.name,
                        style: const TextStyle(
                          fontSize: 18,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${result.totalReps}회',
                        style: const TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: AppTheme.accent,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text('보상동작 ${result.compensationCount}회'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 채널별 평균 활성도 차트
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '근육 평균 활성도',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 180,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: 100,
                            barTouchData: BarTouchData(enabled: false),
                            titlesData: FlTitlesData(
                              leftTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    const labels = ['CH1', 'CH2', 'CH3'];
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(labels[value.toInt()]),
                                    );
                                  },
                                ),
                              ),
                            ),
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            barGroups: [
                              _bar(0, result.avgCh1),
                              _bar(1, result.avgCh2),
                              _bar(2, result.avgCh3),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // AI 코멘트
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.psychology, color: AppTheme.primary),
                          SizedBox(width: 8),
                          Text(
                            'AI 코칭',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        result.comment,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Nav.toHome(context),
                child: const Text('홈으로'),
              ),
            ],
          ),
        ),
      ),
          // confetti 오버레이
          if (_showConfetti)
            Positioned.fill(
              child: ConfettiOverlay(
                onComplete: () {
                  if (mounted) setState(() => _showConfetti = false);
                },
              ),
            ),
        ],
      ),
    );
  }

  BarChartGroupData _bar(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: AppTheme.primary,
          width: 32,
          borderRadius: BorderRadius.circular(6),
        ),
      ],
    );
  }
}
