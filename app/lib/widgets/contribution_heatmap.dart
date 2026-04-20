import 'package:flutter/material.dart';

import '../models/session_record.dart';
import '../theme/app_theme.dart';

/// 최근 30일 운동 히트맵 (5주 × 7일 그리드).
/// 각 셀은 해당 날짜의 반복수에 비례해 색상 강도가 진해짐.
/// 외부에서 카드로 감싸는 것을 전제 — 자체 카드 없음.
class ContributionHeatmap extends StatelessWidget {
  final List<SessionRecord> records;
  const ContributionHeatmap({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subColor =
        isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary;
    final emptyBg = isDark
        ? AppTheme.cardElevatedDark
        : const Color(0xFFEDEFF3);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 34));

    final sessionsByDay = <String, int>{};
    for (final r in records) {
      final d = DateTime(r.date.year, r.date.month, r.date.day);
      if (d.isBefore(start) || d.isAfter(today)) continue;
      final key = _key(d);
      sessionsByDay[key] = (sessionsByDay[key] ?? 0) + 1;
    }
    final activeDays = sessionsByDay.keys.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              '최근 30일',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text(
              '$activeDays일 운동',
              style: TextStyle(fontSize: 12, color: subColor),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            const cols = 7;
            const gap = 6.0;
            final cell = (constraints.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: List.generate(35, (i) {
                final date = start.add(Duration(days: i));
                final sessions = sessionsByDay[_key(date)] ?? 0;
                final isToday = date.year == today.year &&
                    date.month == today.month &&
                    date.day == today.day;
                return _Cell(
                  size: cell,
                  sessions: sessions,
                  day: date.day,
                  isToday: isToday,
                  emptyBg: emptyBg,
                  emptyTextColor: subColor,
                );
              }),
            );
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text('적음', style: TextStyle(fontSize: 11, color: subColor)),
            const SizedBox(width: 8),
            for (final a in const [0.2, 0.4, 0.6, 0.8, 1.0])
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: a),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            const SizedBox(width: 4),
            Text('많음', style: TextStyle(fontSize: 11, color: subColor)),
          ],
        ),
      ],
    );
  }

  String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';
}

class _Cell extends StatelessWidget {
  final double size;
  final int sessions;
  final int day;
  final bool isToday;
  final Color emptyBg;
  final Color emptyTextColor;
  const _Cell({
    required this.size,
    required this.sessions,
    required this.day,
    required this.isToday,
    required this.emptyBg,
    required this.emptyTextColor,
  });

  Color _bg() {
    switch (sessions) {
      case 0:
        return emptyBg;
      case 1:
        return AppTheme.primary.withValues(alpha: 0.30);
      case 2:
        return AppTheme.primary.withValues(alpha: 0.50);
      case 3:
        return AppTheme.primary.withValues(alpha: 0.70);
      case 4:
        return AppTheme.primary.withValues(alpha: 0.88);
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strong = sessions >= 2;
    return Tooltip(
      message: sessions > 0 ? '$sessions회 운동' : '휴식',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _bg(),
          borderRadius: BorderRadius.circular(8),
          border: isToday
              ? Border.all(color: AppTheme.accent, width: 2)
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          '$day',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: strong ? Colors.white : emptyTextColor,
          ),
        ),
      ),
    );
  }
}
