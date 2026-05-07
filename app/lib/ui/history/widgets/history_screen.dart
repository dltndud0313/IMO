import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/dependencies.dart';
import '../../../data/repositories/session_history_repository.dart';
import '../../../domain/models/workout_session.dart';
import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';
import '../view_model/history_viewmodel.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime _visibleMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );
  int _selectedDay = DateTime.now().day;
  late final HistoryViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = HistoryViewModel(getIt<SessionHistoryRepository>());
    _viewModel.addListener(_handleViewModelChanged);
    _loadSelectedDaySessions();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_handleViewModelChanged);
    _viewModel.dispose();
    super.dispose();
  }

  void _handleViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _moveMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
      final lastDay =
          DateUtils.getDaysInMonth(_visibleMonth.year, _visibleMonth.month);
      _selectedDay = _selectedDay.clamp(1, lastDay);
    });
    _loadSelectedDaySessions();
  }

  void _selectDay(int day) {
    setState(() => _selectedDay = day);
    _loadSelectedDaySessions();
  }

  Future<void> _loadSelectedDaySessions() {
    return _viewModel.loadSessionsByDate(_selectedDateText);
  }

  String get _selectedDateText {
    final month = _visibleMonth.month.toString().padLeft(2, '0');
    final day = _selectedDay.toString().padLeft(2, '0');
    return '${_visibleMonth.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '운동 기록',
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MonthSelector(
            visibleMonth: _visibleMonth,
            onPrevious: () => _moveMonth(-1),
            onNext: () => _moveMonth(1),
          ),
          const SizedBox(height: AppSpacing.md),
          _CalendarCard(
            visibleMonth: _visibleMonth,
            selectedDay: _selectedDay,
            onDateSelected: _selectDay,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('$_selectedDateText 요약', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.sm),
          if (_viewModel.loadingSessions)
            const _HistoryInfoCard(message: '운동 기록을 불러오는 중입니다.')
          else if (_viewModel.sessionLoadError != null)
            _HistoryInfoCard(message: _viewModel.sessionLoadError!)
          else if (_viewModel.daySessions.isEmpty)
            const _HistoryInfoCard(message: '이 날의 운동 기록이 없습니다.')
          else
            for (final session in _viewModel.daySessions) ...[
              _DaySummaryCard(
                session: session,
                onTap: () =>
                    context.go('/history-detail?session=${session.sessionId}'),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
        ],
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.visibleMonth,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime visibleMonth;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CircleIconButton(icon: Icons.chevron_left_rounded, onTap: onPrevious),
        const SizedBox(width: AppSpacing.xs),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
            border: Border.all(color: AppColors.border),
          ),
          child: Text('${visibleMonth.year}-${visibleMonth.month}', style: AppTextStyles.sectionTitle),
        ),
        const SizedBox(width: AppSpacing.xs),
        _CircleIconButton(icon: Icons.chevron_right_rounded, onTap: onNext),
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
    return Material(
      color: AppColors.card,
      shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.visibleMonth,
    required this.selectedDay,
    required this.onDateSelected,
  });

  final DateTime visibleMonth;
  final int selectedDay;
  final ValueChanged<int> onDateSelected;

  @override
  Widget build(BuildContext context) {
    const days = ['일', '월', '화', '수', '목', '금', '토'];
    final leadingBlank =
        DateTime(visibleMonth.year, visibleMonth.month).weekday % 7;
    final daysInMonth =
        DateUtils.getDaysInMonth(visibleMonth.year, visibleMonth.month);
    final dates = List<int?>.filled(leadingBlank, null) +
        List<int>.generate(daysInMonth, (i) => i + 1);

    return ImoCard(
      variant: ImoCardVariant.hero,
      paddingSize: ImoCardPadding.lg,
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.25,
            children: [
              for (final day in days)
                Center(
                  child: Text(
                    day,
                    style: AppTextStyles.caption.copyWith(
                      color: day == '일'
                          ? AppColors.error
                          : day == '토'
                          ? AppColors.heatmapLow
                          : AppColors.textTertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              for (final date in dates)
                Center(
                  child: date == null
                      ? const SizedBox.shrink()
                      : GestureDetector(
                          onTap: () => onDateSelected(date),
                          child: _DateCell(
                            date: date,
                            selected: date == selectedDay,
                          ),
                        ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateCell extends StatelessWidget {
  const _DateCell({
    required this.date,
    required this.selected,
  });

  final int date;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: selected ? 52 : 36,
      height: selected ? 52 : 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(
          selected ? AppSpacing.buttonRadius : 18,
        ),
      ),
      child: Text(
        '$date',
        style: AppTextStyles.body.copyWith(
          color: selected ? AppColors.card : AppColors.textPrimary,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
        ),
      ),
    );
  }
}

class _HistoryInfoCard extends StatelessWidget {
  const _HistoryInfoCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      paddingSize: ImoCardPadding.lg,
      child: Center(
        child: Text(
          message,
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _DaySummaryCard extends StatelessWidget {
  const _DaySummaryCard({
    required this.session,
    required this.onTap,
  });

  final WorkoutSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      interactive: true,
      onTap: onTap,
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(session.exerciseType.label, style: AppTextStyles.sectionTitle),
              const Spacer(),
              Text(
                '${session.totalReps}회 · ${session.durationSec ~/ 60}분',
                style: AppTextStyles.body,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                '하루 상세 분석 보기',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.primaryStrong,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primaryStrong,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
