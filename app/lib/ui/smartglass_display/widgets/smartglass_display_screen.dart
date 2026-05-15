import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../config/dependencies.dart';
import '../../../data/services/pi_socket_service.dart';
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
  late final SmartglassDisplayViewModel _viewModel;
  late final bool _ownsViewModel;
  bool _paused = false;
  bool _emergencyStopped = false;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    _viewModel = widget.viewModel ??
        SmartglassDisplayViewModel(
          piSocketService: getIt<PiSocketService>(),
        );
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
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    if (_ownsViewModel) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  void _togglePause() {
    setState(() {
      _paused = !_paused;
    });
  }

  void _triggerEmergencyStop() {
    setState(() {
      _emergencyStopped = true;
      _paused = false;
    });
    context.go('/session-result');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        final state = _viewModel.state;
        final compact = MediaQuery.sizeOf(context).height < 700;

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
                    paused: _paused,
                    emergencyStopped: _emergencyStopped,
                    onPauseToggle: _togglePause,
                    onEmergencyStop: _triggerEmergencyStop,
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
    required this.emergencyStopped,
    required this.onPauseToggle,
    required this.onEmergencyStop,
  });

  final SmartglassDisplayState state;
  final bool compact;
  final bool paused;
  final bool emergencyStopped;
  final VoidCallback onPauseToggle;
  final VoidCallback onEmergencyStop;

  @override
  Widget build(BuildContext context) {
    final emgValues = _emgValues(state);

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
                      child: _TopCard(
                        title: 'EMG 1',
                        value: '${emgValues[0]}%',
                        color: const Color(0xFF70E8CD),
                        compact: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      flex: 10,
                      child: _TopCard(
                        title: 'EMG 2',
                        value: '${emgValues[1]}%',
                        color: const Color(0xFF70E8CD),
                        compact: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      flex: 10,
                      child: _TopCard(
                        title: 'EMG 3',
                        value: '${emgValues[2]}%',
                        color: const Color(0xFF70E8CD),
                        compact: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      flex: 10,
                      child: _TopCard(
                        title: 'EMG 4',
                        value: '${emgValues[3]}%',
                        color: const Color(0xFF70E8CD),
                        compact: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      flex: 14,
                      child: _ControlCard(
                        paused: paused,
                        emergencyStopped: emergencyStopped,
                        onPauseToggle: onPauseToggle,
                        onEmergencyStop: onEmergencyStop,
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

class _CenterStatusCard extends StatelessWidget {
  const _CenterStatusCard({
    required this.state,
    required this.paused,
    required this.emergencyStopped,
    required this.compact,
  });

  final SmartglassDisplayState state;
  final bool paused;
  final bool emergencyStopped;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = _toneColor(state.tone);

    return _GlassPanel(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 24 : 30,
        vertical: compact ? 22 : 28,
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
          const SizedBox(height: 14),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: compact ? 560 : 760,
                  ),
                  child: Text(
                    _mainStatusMessage(state, paused, emergencyStopped),
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
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
            child: LinearProgressIndicator(
              minHeight: compact ? 8 : 10,
              value: state.focusProgress,
              color: accent,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
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
    required this.emergencyStopped,
    required this.onPauseToggle,
    required this.onEmergencyStop,
    required this.compact,
  });

  final bool paused;
  final bool emergencyStopped;
  final VoidCallback onPauseToggle;
  final VoidCallback onEmergencyStop;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 18,
        vertical: compact ? 12 : 16,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            children: [
              Expanded(
                child: _ControlButton(
                  label: emergencyStopped ? '정지됨' : '중지',
                  color: const Color(0xFFFF886F),
                  onTap: emergencyStopped ? null : onEmergencyStop,
                  compact: compact,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ControlButton(
                  label: paused ? '재개' : '일시정지',
                  color: const Color(0xFF70E8CD),
                  onTap: emergencyStopped ? null : onPauseToggle,
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
          vertical: compact ? 12 : 14,
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
  return state.workoutLabel.trim().isEmpty ? '-' : state.workoutLabel;
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

List<int> _emgValues(SmartglassDisplayState state) {
  final base = state.activationPercent.clamp(0, 100);
  if (base == 0) {
    return const [0, 0, 0, 0];
  }

  return [
    base,
    (base - 6).clamp(0, 100),
    (base + 4).clamp(0, 100),
    (base - 2).clamp(0, 100),
  ];
}

String _mainStatusMessage(
  SmartglassDisplayState state,
  bool paused,
  bool emergencyStopped,
) {
  if (emergencyStopped) return '운동을 정지했습니다';
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
