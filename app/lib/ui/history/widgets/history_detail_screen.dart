import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/dependencies.dart';
import '../../../data/repositories/session_history_repository.dart';
import '../../../domain/models/workout_session.dart';
import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';

class HistoryDetailScreen extends StatelessWidget {
  const HistoryDetailScreen({super.key, this.sessionId = ''});

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '운동 상세',
      subtitle: '하루 운동 분석',
      showBackButton: true,
      onBack: () => context.go('/history'),
      scrollable: true,
      body: FutureBuilder<WorkoutSession>(
        future: _loadSession(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _HistoryDetailInfo(
              message: '운동 상세 기록을 불러오는 중입니다.',
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const _HistoryDetailInfo(
              message: '운동 상세 기록을 불러오지 못했습니다.',
            );
          }
          return _SessionDetailCard(session: snapshot.data!);
        },
      ),
    );
  }

  Future<WorkoutSession> _loadSession() {
    if (sessionId.isEmpty) {
      return Future.error(StateError('missing session id'));
    }
    return getIt<SessionHistoryRepository>().getSessionDetail(sessionId);
  }
}

class _HistoryDetailInfo extends StatelessWidget {
  const _HistoryDetailInfo({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      paddingSize: ImoCardPadding.lg,
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _SessionDetailCard extends StatelessWidget {
  const _SessionDetailCard({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final minutes = (session.durationSec / 60).ceil();
    final hasMuscleMap = session.muscleMap?.values.isNotEmpty ?? false;
    final hasBalance = session.balanceSummary?.enabled == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ImoCard(
          paddingSize: ImoCardPadding.lg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(session.exerciseType.label, style: AppTextStyles.sectionTitle),
              const SizedBox(height: AppSpacing.md),
              _InfoLine(label: '총 세트', value: '${session.setCount}세트'),
              _InfoLine(label: '총 반복', value: '${session.totalReps}회'),
              _InfoLine(label: '운동 시간', value: '$minutes분'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ImoCard(
          paddingSize: ImoCardPadding.lg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('분석 데이터', style: AppTextStyles.sectionTitle),
              const SizedBox(height: AppSpacing.md),
              Text(
                hasMuscleMap
                    ? '근육 활성도 데이터가 있습니다.'
                    : '근육 활성도 데이터가 없습니다.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                hasBalance
                    ? '좌우 밸런스 데이터가 있습니다.'
                    : '좌우 밸런스 데이터가 없습니다.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Text(label, style: AppTextStyles.body),
          const Spacer(),
          Text(value, style: AppTextStyles.label),
        ],
      ),
    );
  }
}
