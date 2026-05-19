import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../config/dependencies.dart';
import '../../../data/services/pi_socket_service.dart';
import '../../../domain/models/exercise_type.dart';
import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../model/smartglass_display_models.dart';
import '../view_model/smartglass_display_viewmodel.dart';

class SmartglassDisplayScreen extends StatefulWidget {
  const SmartglassDisplayScreen({
    super.key,
    this.viewModel,
    this.showPreviewPanel = true,
  });

  final SmartglassDisplayViewModel? viewModel;
  final bool showPreviewPanel;

  @override
  State<SmartglassDisplayScreen> createState() =>
      _SmartglassDisplayScreenState();
}

class _SmartglassDisplayScreenState extends State<SmartglassDisplayScreen> {
  static const _sessionResultTimeoutDuration = Duration(seconds: 5);

  late final SmartglassDisplayViewModel _viewModel;
  late final bool _ownsViewModel;
  Timer? _sessionResultTimeout;
  bool _navigatingToResult = false;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    _viewModel = widget.viewModel ??
        SmartglassDisplayViewModel(
          piSocketService: getIt<PiSocketService>(),
        );
    _viewModel.addListener(_handleViewModelChanged);
    if (_ownsViewModel) {
      // 화면에서 직접 생성한 ViewModel 인 경우에만 Pi 메시지 구독을 시작한다.
      // 외부에서 주입된 경우 (미리보기/테스트 등) 에는 호출자가 책임진다.
      _viewModel.startListeningToPi();
    }
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    _sessionResultTimeout?.cancel();
    _viewModel.removeListener(_handleViewModelChanged);
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    if (_ownsViewModel) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  void _handleViewModelChanged() {
    final session = _viewModel.completedSession;
    if (session == null || _navigatingToResult || !mounted) {
      return;
    }

    _navigatingToResult = true;
    _sessionResultTimeout?.cancel();

    final sessionId = Uri.encodeQueryComponent(session.sessionId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.go('/session-result?sessionId=$sessionId', extra: session);
    });
  }

  void _scheduleSessionResultTimeout({String? statusFallback}) {
    _sessionResultTimeout?.cancel();
    _sessionResultTimeout = Timer(_sessionResultTimeoutDuration, () {
      if (!mounted || _navigatingToResult) {
        return;
      }

      _navigatingToResult = true;
      final query = statusFallback == null ? '' : '?status=$statusFallback';
      context.go('/session-result$query');
    });
  }

  void _handlePauseToggle() {
    unawaited(_togglePause());
  }

  Future<void> _togglePause() async {
    try {
      await _viewModel.togglePause();
    } catch (_) {}
  }

  void _handleStopWorkout() {
    unawaited(_stopWorkout());
  }

  Future<void> _stopWorkout() async {
    try {
      final requested = await _viewModel.stopWorkout();
      if (requested) {
        _scheduleSessionResultTimeout(statusFallback: 'stopped');
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        final state = _viewModel.state;
        final compact = MediaQuery.sizeOf(context).height < 700;
        final paused = _viewModel.paused;
        final emergencyStopped = _viewModel.emergencyStopped;
        final awaitingSessionResult = _viewModel.awaitingSessionResult;
        final isConnected = _viewModel.isConnected;
        // Pi 끊김 상태에서도 중지/일시정지 버튼은 활성화한다 (viewmodel 에서
        // 끊긴 채 누른 stop 은 emergency 로 처리, pause 는 로컬 UI 토글).
        final canSendControl = !_viewModel.controlsLocked;

        return AppScaffold(
          horizontalPadding: false,
          verticalPadding: false,
          safeArea: false,
          background: const Color(0xFF02070A),
          body: Stack(
            children: [
              const _HudBackdrop(),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _GlassHudLayout(
                    state: state,
                    compact: compact,
                    paused: paused,
                    awaitingSessionResult: awaitingSessionResult,
                    emergencyStopped: emergencyStopped,
                    canSendControl: canSendControl,
                    onPauseToggle: _handlePauseToggle,
                    onStop: _handleStopWorkout,
                  ),
                ),
              ),
              if (!isConnected)
                const SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: _DisconnectedBanner(),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _GlassHudLayout extends StatelessWidget {
  const _GlassHudLayout({
    required this.state,
    required this.compact,
    required this.paused,
    required this.awaitingSessionResult,
    required this.emergencyStopped,
    required this.canSendControl,
    required this.onPauseToggle,
    required this.onStop,
  });

  final SmartglassDisplayState state;
  final bool compact;
  final bool paused;
  final bool awaitingSessionResult;
  final bool emergencyStopped;
  final bool canSendControl;
  final VoidCallback onPauseToggle;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final emgChannels = _emgChannels(state);
    final hasEmgStream = state.emgChannelPercents.isNotEmpty;

    return Column(
      children: [
        Expanded(
          flex: compact ? 22 : 20,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 10,
                child: _TopCard(
                  title: '운동 종류',
                  value: _workoutName(state),
                  color: const Color(0xFFF1FFF9),
                  compact: compact,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 8,
                child: _TopCard(
                  title: '현재 횟수',
                  value: _repValue(state),
                  color: const Color(0xFFF4CC72),
                  compact: compact,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: _TopCard(
                  title: '세트',
                  value: _setValue(state),
                  color: const Color(0xFFF1FFF9),
                  compact: compact,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          flex: compact ? 52 : 56,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 17,
                child: _CenterStatusCard(
                  state: state,
                  paused: paused,
                  awaitingSessionResult: awaitingSessionResult,
                  emergencyStopped: emergencyStopped,
                  compact: compact,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 7,
                child: Column(
                  children: [
                    Expanded(
                      flex: 10,
                      child: _EmgCard(
                        label: 'EMG 1',
                        value: emgChannels[0],
                        hasStream: hasEmgStream,
                        compact: true,
                      ),
                    ),
                    SizedBox(height: compact ? 8 : 12),
                    Expanded(
                      flex: 10,
                      child: _EmgCard(
                        label: 'EMG 2',
                        value: emgChannels[1],
                        hasStream: hasEmgStream,
                        compact: true,
                      ),
                    ),
                    SizedBox(height: compact ? 8 : 12),
                    Expanded(
                      flex: 10,
                      child: _EmgCard(
                        label: 'EMG 3',
                        value: emgChannels[2],
                        hasStream: hasEmgStream,
                        compact: true,
                      ),
                    ),
                    SizedBox(height: compact ? 8 : 12),
                    Expanded(
                      flex: 10,
                      child: _EmgCard(
                        label: 'EMG 4',
                        value: emgChannels[3],
                        hasStream: hasEmgStream,
                        compact: true,
                      ),
                    ),
                    SizedBox(height: compact ? 8 : 12),
                    Expanded(
                      flex: 12,
                      child: _ControlCard(
                        paused: paused,
                        awaitingSessionResult: awaitingSessionResult,
                        emergencyStopped: emergencyStopped,
                        canSendControl: canSendControl,
                        onPauseToggle: onPauseToggle,
                        onStop: onStop,
                        compact: compact,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DisconnectedBanner extends StatelessWidget {
  const _DisconnectedBanner();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFF886F).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFF886F).withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: Color(0xFFFF886F),
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              'Pi 연결 끊김 — 중지 버튼으로 운동을 종료할 수 있어요',
              style: AppTextStyles.caption.copyWith(
                color: const Color(0xFFFFD9CE),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HudBackdrop extends StatelessWidget {
  const _HudBackdrop();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF02070A),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF02070A),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(18),
        child: child,
      ),
    );
  }
}

class _TopCard extends StatelessWidget {
  const _TopCard({
    required this.title,
    required this.value,
    required this.color,
    required this.compact,
  });

  final String title;
  final String value;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: EdgeInsets.all(compact ? 10 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: const Color(0xFF9FC7BD),
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Flexible(
            flex: 5,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: AppTextStyles.metric.copyWith(
                    fontSize: compact ? 28 : 36,
                    color: color,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// EMG 채널 1개를 표시하는 카드. 숫자(%) + 게이지 바.
/// value 가 null 이면 측정 불가 — 스트림이 있으면 "센서 확인"(분리), 없으면 "—".
class _EmgCard extends StatelessWidget {
  const _EmgCard({
    required this.label,
    required this.value,
    required this.hasStream,
    required this.compact,
  });

  final String label;
  final int? value;
  final bool hasStream;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    final clamped = (value ?? 0).clamp(0, 100).toInt();
    final gaugeColor =
        hasValue ? _emgGaugeColor(clamped) : const Color(0xFF243430);
    final valueText = hasValue ? '$clamped%' : (hasStream ? '센서 확인' : '—');

    return _GlassPanel(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 5 : 9,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 라벨 + 퍼센트를 한 줄에 → 카드 칸이 낮아도(~25px) 들어간다.
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: const Color(0xFF9FC7BD),
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 11 : 13,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                valueText,
                maxLines: 1,
                style: AppTextStyles.metric.copyWith(
                  fontSize: compact ? 15 : 20,
                  height: 1,
                  color: hasValue
                      ? const Color(0xFFE6FFF8)
                      : const Color(0xFF6B8A84),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 4 : 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: clamped / 100,
              minHeight: compact ? 4 : 6,
              backgroundColor: const Color(0xFF13201E),
              valueColor: AlwaysStoppedAnimation<Color>(gaugeColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// 활성도 구간별 게이지 색 — 높을수록 또렷하게 (운동 강도 피드백).
Color _emgGaugeColor(int value) {
  if (value >= 70) return const Color(0xFF4ADE80);
  if (value >= 40) return const Color(0xFF70E8CD);
  return const Color(0xFF3E6F66);
}

class _CenterStatusCard extends StatelessWidget {
  const _CenterStatusCard({
    required this.state,
    required this.paused,
    required this.awaitingSessionResult,
    required this.emergencyStopped,
    required this.compact,
  });

  final SmartglassDisplayState state;
  final bool paused;
  final bool awaitingSessionResult;
  final bool emergencyStopped;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = _toneColor(state.tone);

    return _GlassPanel(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 24 : 30,
        vertical: compact ? 18 : 28,
      ),
      child: Column(
        children: [
          Text(
            '현재 운동상태',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.label.copyWith(
              color: accent,
              fontSize: compact ? 22 : 26,
            ),
          ),
          SizedBox(height: compact ? 10 : 14),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: compact ? 560 : 760,
                  ),
                  child: Text(
                    _mainStatusMessage(
                      state,
                      paused,
                      awaitingSessionResult,
                      emergencyStopped,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: compact ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.metric.copyWith(
                      fontSize: compact ? 42 : 58,
                      color: const Color(0xFFF1FFF9),
                      height: 1.06,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlCard extends StatelessWidget {
  const _ControlCard({
    required this.paused,
    required this.awaitingSessionResult,
    required this.emergencyStopped,
    required this.canSendControl,
    required this.onPauseToggle,
    required this.onStop,
    required this.compact,
  });

  final bool paused;
  final bool awaitingSessionResult;
  final bool emergencyStopped;
  final bool canSendControl;
  final VoidCallback onPauseToggle;
  final VoidCallback onStop;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final stopDisabled = !canSendControl || awaitingSessionResult;
    final pauseDisabled =
        !canSendControl || awaitingSessionResult || emergencyStopped;
    return _GlassPanel(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 18,
        vertical: compact ? 8 : 16,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: _ControlButton(
                  label: awaitingSessionResult ? '정리 중' : '중지',
                  color: const Color(0xFFFFD37F),
                  onTap: stopDisabled ? null : onStop,
                  compact: compact,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ControlButton(
                  label: paused ? '재개' : '일시정지',
                  color: const Color(0xFF70E8CD),
                  onTap: pauseDisabled ? null : onPauseToggle,
                  compact: compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.label,
    required this.color,
    required this.onTap,
    required this.compact,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: EdgeInsets.symmetric(
          horizontal: 10,
          vertical: compact ? 8 : 14,
        ),
        decoration: BoxDecoration(
          color: disabled
              ? Colors.white.withValues(alpha: 0.06)
              : color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.label.copyWith(
              color: disabled ? const Color(0xFF7B8F8A) : color,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 12 : 14,
            ),
          ),
        ),
      ),
    );
  }
}

String _workoutName(SmartglassDisplayState state) {
  final raw = state.workoutLabel.trim();
  if (raw.isEmpty) return '-';
  // workoutLabel 은 Pi 가 보낸 wire 문자열(PUSH_UP, BICEP_CURL...)인 경우가 많다.
  // 다른 화면들과 통일된 한글명(이두컬, 푸시업 등)으로 변환해서 표시.
  try {
    return ExerciseType.fromWire(raw).label;
  } catch (_) {
    return raw;
  }
}

String _repValue(SmartglassDisplayState state) {
  if (state.targetRep > 0) {
    return '${state.repCount}/${state.targetRep}';
  }
  if (state.repCount > 0) {
    return '${state.repCount}';
  }
  return '-';
}

String _setValue(SmartglassDisplayState state) {
  if (state.totalSets > 0) {
    return '${state.currentSet}/${state.totalSets}';
  }
  return '-';
}

/// EMG 1~4 채널별 근활성도(0~100, 분리된 채널은 null).
/// Pi 데이터가 아직 없으면 빈 리스트 → 4칸 모두 null.
List<int?> _emgChannels(SmartglassDisplayState state) {
  final channels = state.emgChannelPercents;
  return List<int?>.generate(
    4,
    (index) => index < channels.length ? channels[index] : null,
  );
}

String _mainStatusMessage(
  SmartglassDisplayState state,
  bool paused,
  bool awaitingSessionResult,
  bool emergencyStopped,
) {
  if (emergencyStopped) return '긴급 중지를 요청했습니다';
  if (awaitingSessionResult) return '운동 결과를 정리하고 있습니다';
  if (paused) return '운동이 일시정지되었습니다';
  if (state.isResting) return '휴식 ${state.restSeconds}초';
  if (state.isCalibrating) {
    return '캘리브레이션 ${state.focusProgressLabel.replaceFirst('캘리브레이션 ', '')}';
  }
  if (_isPerfectState(state)) return '완벽합니다';
  return state.primaryMessage;
}

bool _isPerfectState(SmartglassDisplayState state) {
  return state.sessionPhase == SmartglassSessionPhase.workoutActive &&
      state.tone == SmartglassDisplayTone.good;
}

Color _toneColor(SmartglassDisplayTone tone) {
  switch (tone) {
    case SmartglassDisplayTone.good:
      return const Color(0xFF7BFFB2);
    case SmartglassDisplayTone.warn:
      return const Color(0xFFFFD37F);
    case SmartglassDisplayTone.danger:
      return const Color(0xFFFF886F);
    case SmartglassDisplayTone.neutral:
      return const Color(0xFF70E8CD);
  }
}
