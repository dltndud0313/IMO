# Session Result Screen 와이어링 작업 플랜

> 이 문서는 작업 계획 + 바로 붙여 쓸 수 있는 코드 스니펫을 포함한다.
> 팀원이 라우터 충돌 가능성이 있어 사전 공유용으로 작성.

## 배경

`app/lib/ui/session_result/widgets/session_result_screen.dart`가 운동 종료 직후 표시되는 화면인데, 현재 **표시되는 모든 수치가 const 하드코딩** 상태다.

- 총 횟수: `33`
- 유효 횟수: `31`
- 운동 시간: `7분 12초`
- 보상동작: `4`
- 세트별 결과: `const _setResults` 더미 리스트
- 근육 히트맵: 좌표 박힌 가짜 `_HeatPoint(label: '가슴 68%', ...)`
- 코멘트: 고정 문구

라우팅도 `/session-result?status=stopped`로 status 쿼리 파라미터만 넘기는데, 그 status조차 화면에서 소비되지 않는다. 어떤 운동을 했든 항상 같은 결과가 표시됨.

### 추가로 발견된 사항

- `app/lib/ui/session_result/view_model/session_result_viewmodel.dart`는 `// TODO: 구현` 한 줄짜리 빈 stub
- `_WorkoutState.reportWaiting` 상태가 정의돼 있지만 실제 흐름에선 안 쓰이고 UI preview 모드에서만 진입
- 며칠 전 추가한 `mascot_report_wait.png`도 실 모드에선 안 보이는 상태
- `EndWorkoutSessionUseCase.listenAndSaveAutomatically()`가 이미 sessionResult 스트림 구독해서 로컬/백엔드 저장은 자동으로 일어남 (FR-43~45)
- 백엔드 `GET /sessions/{id}` 응답에 `muscleMap` 필드는 이미 포함 (이전 작업에서 추가 완료)
- `api_service._normalizeSessionDetail`이 이미 `muscleMap` (camelCase) → `muscle_map` (snake_case) 키 정규화

## 목표

1. SessionResultScreen이 **실제 세션 데이터**를 표시.
2. 운동 종료 직후뿐 아니라 **나중에 히스토리에서 진입**해도 재사용 가능한 구조로.
3. 기존 `HistoryDetailScreen`이 따르는 `FutureBuilder` + Repository 직접 호출 패턴 일관 유지.
4. 이미 만들어진 `mascot_report_wait.png` 대기 화면을 운동 종료 흐름에서 활용.

## 접근: Hybrid (라우트 sessionId + go_router extra)

라우트가 **두 가지 진입 경로**를 모두 지원하도록 설계:

| 진입 경로 | 방식 |
|---|---|
| 운동 종료 직후 | go_router `extra`에 `WorkoutSession` 객체 직접 전달 → 즉시 표시, race condition 없음 |
| 히스토리에서 진입 / 새로고침 | 쿼리 파라미터 `sessionId`로 `GET /sessions/{id}` 호출 |

화면 측에서는 `initialSession`이 있으면 우선 사용, 없으면 `sessionId`로 fetch.

ViewModel 신설 없이 `FutureBuilder + Repository` 직접 호출 (= `HistoryDetailScreen` 패턴).

## 영향 받는 파일 (협업 코디용)

| 파일 | 범위 | 충돌 위험 |
|---|---|---|
| `app/lib/config/router.dart` | `/session-result` 라우트 정의 한 곳 (3~5줄) | **있음** — 다른 팀원이 라우트 추가/수정 시 머지 충돌 가능. 머지 직전 sync 필요 |
| `app/lib/ui/workout/widgets/workout_screen.dart` | 종료/비상정지 흐름 + 스트림 구독 (~60줄) | 워크아웃 화면 작업과 겹칠 수 있음 |
| `app/lib/ui/workout/view_model/workout_viewmodel.dart` | `startListening`에 sessionResult 콜백 추가 (~15줄) | 낮음 |
| `app/lib/ui/session_result/widgets/session_result_screen.dart` | 메인 작업, 거의 재작성 (~430줄) | 낮음 |
| `app/lib/ui/session_result/view_model/session_result_viewmodel.dart` | 삭제 (선택) | 낮음 |

### 추가로 읽기만 하는 파일 (수정 없음)
- `app/lib/data/repositories/session_history_repository.dart` — `getSessionDetail` 호출 측
- `app/lib/data/repositories/workout_repository.dart` — `sessionResult` 스트림 소비
- `app/lib/data/services/api_service.dart` — `_normalizeSessionDetail`이 이미 muscleMap 정규화 (이전 작업)
- `app/lib/ui/history/widgets/history_detail_screen.dart` — `_MuscleActivityCard` 위젯 패턴 참조용

---

## Phase 1. 라우트 시그니처 변경

### `app/lib/config/router.dart`

#### 변경 위치 1: 임포트 추가

```dart
import '../domain/models/workout_session.dart';
```

#### 변경 위치 2: `/session-result` 라우트 빌더

**Before:**
```dart
GoRoute(
  path: '/session-result',
  builder: (context, state) => const SessionResultScreen(),
),
```

**After:**
```dart
GoRoute(
  path: '/session-result',
  builder: (context, state) => SessionResultScreen(
    sessionId: state.uri.queryParameters['sessionId'] ?? '',
    initialSession:
        state.extra is WorkoutSession ? state.extra as WorkoutSession : null,
  ),
),
```

---

## Phase 2. workout_screen 종료 흐름 + viewmodel 스트림 추가

### `app/lib/ui/workout/view_model/workout_viewmodel.dart`

**전체 파일을 다음과 같이 교체:**

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/device_connection_repository.dart';
import '../../../data/repositories/workout_repository.dart';
import '../../../data/services/pi_message.dart';
import '../../../domain/models/workout_session.dart';

class WorkoutViewModel {
  WorkoutViewModel(
    this._workoutRepository,
    this._deviceConnectionRepository,
  );

  final WorkoutRepository _workoutRepository;
  final DeviceConnectionRepository _deviceConnectionRepository;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _pausedSubscription;
  StreamSubscription? _resumedSubscription;
  StreamSubscription? _sessionResultSubscription;

  void startListening({
    required ValueChanged<ConnectionStatusMessage> onConnectionStatus,
    required VoidCallback onPaused,
    required VoidCallback onResumed,
    required ValueChanged<WorkoutSession> onSessionResult,
  }) {
    _connectionSubscription ??=
        _deviceConnectionRepository.systemStatus.listen((status) {
      onConnectionStatus(status);
    });
    _pausedSubscription ??= _workoutRepository.workoutPaused.listen((_) {
      onPaused();
    });
    _resumedSubscription ??= _workoutRepository.workoutResumed.listen((_) {
      onResumed();
    });
    _sessionResultSubscription ??=
        _workoutRepository.sessionResult.listen((session) {
      onSessionResult(session);
    });
  }

  void pauseWorkout() {
    _workoutRepository.pauseWorkout();
  }

  void resumeWorkout() {
    _workoutRepository.resumeWorkout();
  }

  void stopWorkout({
    String reason = 'user_request',
    bool saveResult = true,
  }) {
    _workoutRepository.stopWorkout(
      reason: reason,
      saveResult: saveResult,
    );
  }

  void emergencyStop() {
    _workoutRepository.emergencyStop();
  }

  void dispose() {
    _connectionSubscription?.cancel();
    _pausedSubscription?.cancel();
    _resumedSubscription?.cancel();
    _sessionResultSubscription?.cancel();
  }
}
```

### `app/lib/ui/workout/widgets/workout_screen.dart`

#### 변경 위치 1: 임포트 추가

```dart
import '../../../domain/models/workout_session.dart';
```

#### 변경 위치 2: `_WorkoutScreenState`에 필드 추가

```dart
class _WorkoutScreenState extends State<WorkoutScreen>
    with SingleTickerProviderStateMixin {
  // ... 기존 필드들 ...
  Timer? _sessionResultTimeout;
  bool _navigatingAfterStop = false;
  static const _sessionResultTimeoutDuration = Duration(seconds: 5);
```

#### 변경 위치 3: `initState`의 `startListening` 호출에 콜백 추가

```dart
_workoutViewModel.startListening(
  onConnectionStatus: (_) {},
  onPaused: () {
    if (mounted) {
      setState(() => _state = _WorkoutState.paused);
      _syncMascotAnimation();
    }
  },
  onResumed: () {
    if (mounted) {
      setState(() => _state = _WorkoutState.running);
      _syncMascotAnimation();
    }
  },
  onSessionResult: _handleSessionResult,
);
```

#### 변경 위치 4: 새 메서드 추가

```dart
void _handleSessionResult(WorkoutSession session) {
  if (!mounted) return;
  // 종료 흐름 진입 후에만 navigate. running/paused 상태에서 들어오는 잔여 메시지는 무시.
  if (_state != _WorkoutState.reportWaiting &&
      _state != _WorkoutState.emergency) {
    return;
  }
  if (_navigatingAfterStop) return;
  _navigatingAfterStop = true;
  _sessionResultTimeout?.cancel();
  context.go(
    '/session-result?sessionId=${Uri.encodeQueryComponent(session.sessionId)}',
    extra: session,
  );
}

void _scheduleSessionResultTimeout({String? statusFallback}) {
  _sessionResultTimeout?.cancel();
  _sessionResultTimeout = Timer(_sessionResultTimeoutDuration, () {
    if (!mounted) return;
    if (_navigatingAfterStop) return;
    _navigatingAfterStop = true;
    final query = statusFallback != null ? '?status=$statusFallback' : '';
    context.go('/session-result$query');
  });
}
```

#### 변경 위치 5: `_finishWorkout` 교체

**Before:**
```dart
Future<void> _finishWorkout() async {
  if (AppRuntimeFlags.uiPreviewMode) {
    setState(() => _state = _WorkoutState.reportWaiting);
    _syncMascotAnimation();
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => ImoConfirmDialog(
      message: '운동을 정지하시겠습니까?',
      confirmLabel: '정지',
      cancelLabel: '계속',
      danger: true,
      onConfirm: () {
        try {
          _workoutViewModel.stopWorkout();
        } catch (_) {}
        Navigator.of(dialogContext).pop();
        context.go('/session-result?status=stopped');
      },
    ),
  );
}
```

**After:**
```dart
Future<void> _finishWorkout() async {
  if (AppRuntimeFlags.uiPreviewMode) {
    setState(() => _state = _WorkoutState.reportWaiting);
    _syncMascotAnimation();
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => ImoConfirmDialog(
      message: '운동을 정지하시겠습니까?',
      confirmLabel: '정지',
      cancelLabel: '계속',
      danger: true,
      onConfirm: () {
        try {
          _workoutViewModel.stopWorkout();
        } catch (_) {}
        Navigator.of(dialogContext).pop();
        if (!mounted) return;
        setState(() => _state = _WorkoutState.reportWaiting);
        _syncMascotAnimation();
        _scheduleSessionResultTimeout(statusFallback: 'stopped');
      },
    ),
  );
}
```

#### 변경 위치 6: `_emergencyStop` 교체

**Before:**
```dart
void _emergencyStop() {
  if (AppRuntimeFlags.uiPreviewMode) {
    setState(() => _state = _WorkoutState.emergency);
    _syncMascotAnimation();
    return;
  }

  try {
    _workoutViewModel.emergencyStop();
  } catch (_) {}
  context.go('/session-result?status=emergency_stopped');
}
```

**After:**
```dart
void _emergencyStop() {
  if (AppRuntimeFlags.uiPreviewMode) {
    setState(() => _state = _WorkoutState.emergency);
    _syncMascotAnimation();
    return;
  }

  try {
    _workoutViewModel.emergencyStop();
  } catch (_) {}
  if (!mounted) return;
  setState(() => _state = _WorkoutState.emergency);
  _syncMascotAnimation();
  _scheduleSessionResultTimeout(statusFallback: 'emergency_stopped');
}
```

#### 변경 위치 7: `dispose`에 timer cancel 추가

```dart
@override
void dispose() {
  _sessionResultTimeout?.cancel();
  _mascotFrameTimer?.cancel();
  _floatController.dispose();
  _workoutViewModel.dispose();
  super.dispose();
}
```

---

## Phase 3 & 4. SessionResultScreen 재작성

### `app/lib/ui/session_result/widgets/session_result_screen.dart`

**파일 전체를 다음으로 교체:**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/dependencies.dart';
import '../../../data/repositories/session_history_repository.dart';
import '../../../domain/models/exercise_type.dart';
import '../../../domain/models/set_result.dart';
import '../../../domain/models/workout_session.dart';
import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';

class SessionResultScreen extends StatefulWidget {
  const SessionResultScreen({
    super.key,
    required this.sessionId,
    this.initialSession,
  });

  final String sessionId;
  final WorkoutSession? initialSession;

  @override
  State<SessionResultScreen> createState() => _SessionResultScreenState();
}

class _SessionResultScreenState extends State<SessionResultScreen> {
  late final Future<WorkoutSession?> _future;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSession;
    if (initial != null) {
      _future = Future.value(initial);
    } else if (widget.sessionId.isEmpty) {
      _future = Future.value(null);
    } else {
      _future = getIt<SessionHistoryRepository>()
          .getSessionDetail(widget.sessionId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '운동 결과',
      scrollable: true,
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ImoButton(
            label: '홈으로 돌아가기',
            onPressed: () => context.go('/home'),
          ),
          const SizedBox(height: AppSpacing.xs),
          ImoButton(
            label: '기록 보기',
            variant: ImoButtonVariant.outline,
            onPressed: () => context.go('/history'),
          ),
        ],
      ),
      body: FutureBuilder<WorkoutSession?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _ResultInfo(message: '결과를 불러오는 중입니다.');
          }
          if (snapshot.hasError) {
            return const _ResultInfo(message: '결과를 불러오지 못했습니다.');
          }
          final session = snapshot.data;
          if (session == null) {
            return const _ResultInfo(
              message: '저장된 운동 결과가 없습니다.\n비상 종료된 운동은 결과가 저장되지 않을 수 있어요.',
            );
          }
          return _ResultContent(session: session);
        },
      ),
    );
  }
}

class _ResultInfo extends StatelessWidget {
  const _ResultInfo({required this.message});

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

class _ResultContent extends StatelessWidget {
  const _ResultContent({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final hasMuscleMap =
        session.muscleMap != null && session.muscleMap!.values.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ResultHeroCard(session: session),
        const SizedBox(height: AppSpacing.sectionGap),
        _ResultMetricGrid(session: session),
        const SizedBox(height: AppSpacing.md),
        _SetResultsCard(setResults: session.setResults),
        if (hasMuscleMap) ...[
          const SizedBox(height: AppSpacing.md),
          _MuscleActivityCard(
            muscleMap: session.muscleMap!.values,
            exerciseType: session.exerciseType,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        _SessionCommentCard(comment: session.comment),
      ],
    );
  }
}

class _ResultHeroCard extends StatelessWidget {
  const _ResultHeroCard({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      variant: ImoCardVariant.hero,
      paddingSize: ImoCardPadding.lg,
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.secondary],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.24),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: AppColors.card,
              size: 42,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '${session.exerciseType.label} 완료',
            style: AppTextStyles.title,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '운동 결과가 저장되었어요. 기록에서 다시 확인할 수 있습니다.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body,
          ),
        ],
      ),
    );
  }
}

class _ResultMetricGrid extends StatelessWidget {
  const _ResultMetricGrid({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final minutes = session.durationSec ~/ 60;
    final seconds = session.durationSec % 60;
    final durationLabel =
        minutes > 0 ? '$minutes분 $seconds초' : '$seconds초';

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.42,
      children: [
        _MetricTile(
          icon: Icons.fitness_center_rounded,
          label: '총 횟수',
          value: '${session.totalReps}',
          tint: AppColors.primary,
        ),
        _MetricTile(
          icon: Icons.check_circle_rounded,
          label: '유효 횟수',
          value: '${session.validReps}',
          tint: AppColors.success,
        ),
        _MetricTile(
          icon: Icons.timer_rounded,
          label: '운동 시간',
          value: durationLabel,
          tint: AppColors.warning,
        ),
        _MetricTile(
          icon: Icons.warning_amber_rounded,
          label: '보상동작',
          value: '${session.compensationCount}',
          tint: AppColors.error,
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      paddingSize: ImoCardPadding.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppSpacing.sm),
            ),
            child: Icon(icon, color: tint, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: AppTextStyles.sectionTitle),
              const SizedBox(height: AppSpacing.xxs),
              Text(label, style: AppTextStyles.caption),
            ],
          ),
        ],
      ),
    );
  }
}

class _SetResultsCard extends StatelessWidget {
  const _SetResultsCard({required this.setResults});

  final List<SetResult> setResults;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('세트별 결과', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.md),
          if (setResults.isEmpty)
            Text(
              '세트 기록이 없습니다.',
              style:
                  AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            )
          else
            for (var i = 0; i < setResults.length; i++) ...[
              _SetResultRow(result: setResults[i]),
              if (i < setResults.length - 1)
                const SizedBox(height: AppSpacing.sm),
            ],
        ],
      ),
    );
  }
}

class _SetResultRow extends StatelessWidget {
  const _SetResultRow({required this.result});

  final SetResult result;

  @override
  Widget build(BuildContext context) {
    final completed = result.actualReps >= result.targetReps;

    return ImoCard(
      variant:
          completed ? ImoCardVariant.subtle : ImoCardVariant.outlined,
      paddingSize: ImoCardPadding.sm,
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: completed ? AppColors.success : AppColors.warning,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${result.setIndex}',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.card,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${result.setIndex}세트', style: AppTextStyles.label),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${result.actualReps}/${result.targetReps}회 · ${_formatSpeed(result.avgSpeed)}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          StatusBadge(
            label: completed ? '완료' : '미달',
            variant: completed ? StatusVariant.success : StatusVariant.warning,
          ),
        ],
      ),
    );
  }

  static String _formatSpeed(String avgSpeed) {
    return switch (avgSpeed.toLowerCase()) {
      'fast' => '빠름',
      'slow' => '느림',
      'normal' => '보통',
      _ => avgSpeed,
    };
  }
}

class _MuscleActivityCard extends StatelessWidget {
  const _MuscleActivityCard({
    required this.muscleMap,
    required this.exerciseType,
  });

  final Map<String, double> muscleMap;
  final ExerciseType exerciseType;

  @override
  Widget build(BuildContext context) {
    final entries = _buildEntries(muscleMap, exerciseType);
    return ImoCard(
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.show_chart_rounded,
                size: 18,
                color: AppColors.primaryStrong,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text('근육 활성도', style: AppTextStyles.label),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (entries.isEmpty)
            Text(
              '근육 활성도 데이터가 없습니다.',
              style:
                  AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            )
          else ...[
            for (var i = 0; i < entries.length; i++) ...[
              _ActivityBar(entry: entries[i]),
              if (i < entries.length - 1)
                const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.md),
            const _ActivityLegend(),
          ],
        ],
      ),
    );
  }

  // NOTE: Pi가 실제 송신하는 키(`chest`, `left_shoulder` 등)를 직접 사용.
  // `exercise_sensor_mapping.dart`의 schema 키는 anatomical 명명으로 작성됐지만
  // 현재 화면 어디서도 참조되지 않는 dead code이며 Pi 키와 정합이 안 맞음.
  // schema 정합성 정리는 "별도 작업: schema 정합성 정렬" 섹션 참고.
  static List<_MuscleEntry> _buildEntries(
    Map<String, double> map,
    ExerciseType exerciseType,
  ) {
    final entries = <_MuscleEntry>[];
    void addAvg(String label, List<String> keys) {
      final present = keys.where(map.containsKey).toList();
      if (present.isEmpty) return;
      final avg =
          present.fold<double>(0, (sum, k) => sum + (map[k] ?? 0)) /
              present.length;
      entries.add(_MuscleEntry(label: label, pct: avg));
    }

    switch (exerciseType) {
      case ExerciseType.pushUp:
        addAvg('대흉근', ['chest']);
        addAvg('어깨', ['left_shoulder', 'right_shoulder']);
        addAvg('삼두근', ['left_triceps', 'right_triceps']);
      case ExerciseType.lateralRaise:
        addAvg('측면 삼각근', ['left_shoulder', 'right_shoulder']);
        addAvg('승모근', ['left_upper_trapezius', 'right_upper_trapezius']);
      case ExerciseType.bicepCurl:
        addAvg('이두근', ['left_biceps', 'right_biceps']);
        addAvg('전완근', ['left_forearm', 'right_forearm']);
    }

    return entries;
  }
}

class _ActivityBar extends StatelessWidget {
  const _ActivityBar({required this.entry});

  final _MuscleEntry entry;

  @override
  Widget build(BuildContext context) {
    final classification = _classifyActivity(entry.pct);
    final fraction = (entry.pct / 100).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(entry.label, style: AppTextStyles.body),
            const Spacer(),
            Text(
              '${entry.pct.toStringAsFixed(0)}% · ${classification.label}',
              style: AppTextStyles.caption,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: AppColors.disabledBg,
            valueColor: AlwaysStoppedAnimation(classification.color),
          ),
        ),
      ],
    );
  }
}

class _ActivityLegend extends StatelessWidget {
  const _ActivityLegend();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendDot(color: AppColors.primary, label: '낮음'),
        SizedBox(width: AppSpacing.md),
        _LegendDot(color: AppColors.success, label: '보통'),
        SizedBox(width: AppSpacing.md),
        _LegendDot(color: AppColors.warning, label: '높음'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xxs),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}

class _MuscleEntry {
  const _MuscleEntry({required this.label, required this.pct});

  final String label;
  final double pct;
}

class _ActivityClassification {
  const _ActivityClassification({required this.label, required this.color});

  final String label;
  final Color color;
}

_ActivityClassification _classifyActivity(double pct) {
  if (pct >= 70) {
    return const _ActivityClassification(
      label: '높음',
      color: AppColors.warning,
    );
  }
  if (pct >= 40) {
    return const _ActivityClassification(
      label: '보통',
      color: AppColors.success,
    );
  }
  return const _ActivityClassification(
    label: '낮음',
    color: AppColors.primary,
  );
}

class _SessionCommentCard extends StatelessWidget {
  const _SessionCommentCard({required this.comment});

  final String? comment;

  @override
  Widget build(BuildContext context) {
    final trimmed = comment?.trim();
    final hasComment = trimmed != null && trimmed.isNotEmpty;
    final message = hasComment
        ? trimmed
        : '오늘 운동 데이터가 잘 저장되었어요. 기록 탭에서 더 자세히 확인해보세요.';

    return ImoCard(
      variant: ImoCardVariant.subtle,
      paddingSize: ImoCardPadding.lg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.insights_rounded,
            color: AppColors.primaryStrong,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('세션 코멘트', style: AppTextStyles.label),
                const SizedBox(height: AppSpacing.xs),
                Text(message, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## Phase 5. 빈 stub 정리

### `app/lib/ui/session_result/view_model/session_result_viewmodel.dart`

현재 내용:
```dart
// 세션 결과 ViewModel
// 의존: SessionHistoryRepository
// FR-43 ~ FR-45
// TODO: 구현
```

**추천: 파일 삭제.**

이유:
- `HistoryDetailScreen`도 별도 viewmodel 없이 `FutureBuilder` + Repository 직접 호출
- 향후 공유/삭제/메모 기능 등 ViewModel 필요한 동작 붙일 때 다시 만들면 됨
- 빈 stub은 "구현 안 됐다"는 인상만 줌

`getIt`/`dependencies.dart`에 등록돼 있지 않으면 import 충돌 없음. (등록돼 있으면 같이 제거.)

---

## Phase 6. 검증

- [ ] 운동 → 정상 종료 → 결과 화면에서 **실제 세트/횟수/시간/보상동작** 표시 확인
- [ ] 운동 → 비상정지 → 결과 화면(또는 fallback 카드) 표시 확인
- [ ] 운동 종료 후 5초 이내 sessionResult 메시지 안 오면 fallback 화면 진입 확인
- [ ] 운동 종료 ~ 결과 화면 사이 `mascot_report_wait.png` 잠깐이라도 보이는지
- [ ] `flutter analyze` 0 issue
- [ ] (옵션) 히스토리에서 세션 탭 → 같은 화면 재사용 가능 확인 (이번 작업 범위 밖)

---

## 별도 작업: schema 정합성 정렬

`exercise_sensor_mapping.dart`와 `muscle_map_schema.dart`는 anatomical 명명(`left_chest`, `left_lateral_deltoid` 등)으로 작성됐지만 Pi가 실제 송신하는 키와 안 맞아 현재 dead code 상태. 이번 SessionResultScreen 작업과는 **독립적**으로 schema 키를 Pi 키 기준으로 rename해 정합성 확보.

### 왜 rename이지 매핑 레이어가 아닌지

매핑이 깔끔한 1:1이 아니라서. 핵심은 **pushup chest**: Pi가 ch1+ch2 평균해서 `chest` 단일 키로 송신, schema는 `left_chest`/`right_chest` 좌우 분리 기대. 매핑하려면 없는 좌우 정보를 만들어내야 함. 또 `lateral_raise`의 `upper_trapezius`는 Pi가 아예 안 보냄. schema가 실제 데이터를 반영하게 만드는 게 정직함.

### 변경 대상

**`app/lib/domain/models/exercise_sensor_mapping.dart`** — `muscleMapKeys`와 관련 `SensorPlacement.dataKey` 정렬:

```dart
// pushup
muscleMapKeys: [
  'chest',              // ← Pi 단일 키 (ch1+ch2 평균)
  'left_shoulder',
  'right_shoulder',
  'left_triceps',
  'right_triceps',
],

// lateral_raise (upper_trapezius는 Pi가 안 보내므로 제거)
muscleMapKeys: [
  'left_shoulder',      // ← Pi 명명. anatomical로는 lateral_deltoid
  'right_shoulder',
],

// bicep_curl (거의 그대로)
muscleMapKeys: [
  'left_biceps',
  'right_biceps',
  'left_forearm',
  'right_forearm',
],
```

**`app/lib/domain/models/muscle_map_schema.dart`** — `MuscleMapKeyDefinition`의 `key` 필드를 위와 동일하게 rename. `displayName`은 한글이라 그대로 두면 됨 (필요 시 살짝 다듬기).

### 영향 범위

- schema가 화면에 안 쓰이므로 **동작 변화 0**
- schema 자체는 실제 데이터와 정합 상태로 들어감 → 미래에 schema 참조하는 코드 작성 시 안전
- HistoryDetailScreen, SessionResultScreen의 인라인 매핑은 **그대로 유지** (별도 리팩 없음)

### 잃는 것 / 얻는 것

| | |
|---|---|
| 잃는 것 | anatomical 명명 정밀도 (`left_chest`/`right_chest` 같은 표현) |
| 얻는 것 | schema가 실제 데이터와 정합 / 매핑 레이어 불필요 / 한 곳에서 진실 관리 |

Pi 하드웨어 4채널 EMG 한계가 명확하니까 schema가 그 한계를 반영하는 게 맞음.

### 독립성

이 작업은 SessionResultScreen 와이어링과 **의존성 없음**. 같은 브랜치에서 별도 커밋으로 추가하거나, 다른 브랜치/PR로 빼도 됨.

---

## 결정 사항 (팀 협의 필요)

1. **라우트 변경 충돌**: `/session-result` 라우트 빌더 함수 수정 시 다른 PR과 머지 충돌 위험. develop 머지 직전 sync 필수.
2. **ViewModel stub 처리**: 삭제 vs 보존. 추천 = 삭제.
3. **히스토리 → session detail 진입**: 이번 작업에서는 SessionResultScreen이 sessionId를 받게만 해두고, 실제 진입 라우팅(`/session-result?sessionId=xxx`로 history 화면에서 push)은 별도 작업으로.
4. **schema 정합성 정렬 포함 여부**: 같은 PR에 묶을지, 별도 PR로 뺄지. 추천 = 같은 PR이지만 별도 커밋.

---

## 커밋 분해

브랜치 한 개, 작은 커밋 여러 개 스타일:

1. `feat(app): route session-result with sessionId and initial session`
   - `router.dart` (Phase 1)
2. `feat(app): wait for session result before navigating from workout screen`
   - `workout_viewmodel.dart` (Phase 2: 콜백 추가)
   - `workout_screen.dart` (Phase 2: 흐름 변경)
3. `feat(app): wire session result screen to real session data`
   - `session_result_screen.dart` (Phase 3 + 4: 메인 작업)
4. `chore(app): remove unused session result viewmodel stub`
   - `session_result_viewmodel.dart` 삭제 (Phase 5, 결정 후)
5. `chore(app): align muscle map schema keys with pi output`
   - `exercise_sensor_mapping.dart`, `muscle_map_schema.dart` (별도 작업)
   - SessionResultScreen 와이어링과 의존성 없음. 같은 PR/브랜치 안에서 진행하되 커밋 분리.

---

## 의도적으로 안 건드릴 것

- `EndWorkoutSessionUseCase`의 자동 저장 로직 — 이미 동작 중. 우리는 같은 스트림을 추가 구독만 함
- `_normalizeSessionDetail` (API 응답 정규화) — 이전 작업에서 muscleMap 처리 추가 완료
- 통계 탭의 인체 히트맵 — 다른 팀원 작업 범위
- 빈 상태 CTA 개선 — 별도 작업
- `WorkoutRepository.sessionResult` 스트림 시그니처 — 그대로 유지

---

## 백엔드 사전 조건 (이미 충족됨)

확인용으로만 명시. 이번 작업으로는 백엔드 변경 없음:

- `GET /sessions/{session_id}` 응답에 `muscleMap` 필드 포함 ✅
  - 위치: `backend/api/routes/sessions.py` 안 `get_session_detail` 함수
- `WorkoutMuscleMap` 값이 percent로 저장됨 (ratio가 아님) ✅
- `_normalizeSessionDetail`이 `muscleMap` (camelCase) → `muscle_map` (snake_case) 키 정규화 ✅
- 앱 `WorkoutSession.fromJson`이 `muscle_map` 필드 파싱 ✅
