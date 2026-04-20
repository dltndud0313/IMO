import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 월간 캘린더 위젯.
/// 운동한 날을 표시하고, 날짜 탭 시 콜백.
class CalendarWidget extends StatelessWidget {
  final int year;
  final int month;
  final Set<int> activeDays; // 운동한 날짜(day)의 집합
  final ValueChanged<DateTime>? onDayTap;
  final VoidCallback? onPrevMonth;
  final VoidCallback? onNextMonth;

  const CalendarWidget({
    super.key,
    required this.year,
    required this.month,
    required this.activeDays,
    this.onDayTap,
    this.onPrevMonth,
    this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary;
    final subColor =
        isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary;
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startWeekday = firstDay.weekday; // 1=Mon

    const weekLabels = ['월', '화', '수', '목', '금', '토', '일'];
    final monthName = '$year년 $month월';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: onPrevMonth,
                ),
                Text(
                  monthName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: onNextMonth,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 요일 헤더
            Row(
              children: weekLabels
                  .map((l) => Expanded(
                        child: Center(
                          child: Text(
                            l,
                            style: TextStyle(
                              fontSize: 12,
                              color: subColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 4),
            // 날짜 그리드
            ...List.generate(_weekCount(startWeekday, daysInMonth), (week) {
              return Row(
                children: List.generate(7, (col) {
                  final dayIndex =
                      week * 7 + col - (startWeekday - 1) + 1;
                  if (dayIndex < 1 || dayIndex > daysInMonth) {
                    return const Expanded(child: SizedBox(height: 40));
                  }
                  final isActive = activeDays.contains(dayIndex);
                  final isToday = year == DateTime.now().year &&
                      month == DateTime.now().month &&
                      dayIndex == DateTime.now().day;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          onDayTap?.call(DateTime(year, month, dayIndex)),
                      child: Container(
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppTheme.primary.withValues(alpha: 0.15)
                              : null,
                          borderRadius: BorderRadius.circular(8),
                          border: isToday
                              ? Border.all(
                                  color: AppTheme.primary, width: 1.5)
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$dayIndex',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                                color: isActive
                                    ? AppTheme.primary
                                    : textColor,
                              ),
                            ),
                            if (isActive)
                              Container(
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                  color: AppTheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              );
            }),
          ],
        ),
      ),
    );
  }

  int _weekCount(int startWeekday, int daysInMonth) {
    return ((startWeekday - 1 + daysInMonth) / 7).ceil();
  }
}
