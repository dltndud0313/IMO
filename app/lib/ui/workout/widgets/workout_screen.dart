import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_runtime_flags.dart';
import '../../../config/dependencies.dart';
import '../../../data/repositories/device_connection_repository.dart';
import '../../../data/repositories/workout_repository.dart';
import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';
import '../view_model/workout_viewmodel.dart';

enum _WorkoutState { running, paused, resting, reportWaiting, emergency }

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen>
    with SingleTickerProviderStateMixin {
  static const _activeMascotAssets = [
    'assets/images/mascot_workout_01.png',
    'assets/images/mascot_workout_02.png',
    'assets/images/mascot_workout_03.png',
  ];

  late final WorkoutViewModel _workoutViewModel;
  late final AnimationController _floatController;
  late final Animation<double> _floatAnimation;
  _WorkoutState _state = _WorkoutState.running;
  Timer? _mascotFrameTimer;
  int _mascotFrameIndex = 0;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -5, end: 5).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
    final repo = getIt<WorkoutRepository>();
    _workoutViewModel = WorkoutViewModel(
      repo,
      getIt<DeviceConnectionRepository>(),
    );
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
    );
    _syncMascotAnimation();
  }

  @override
  void dispose() {
    _mascotFrameTimer?.cancel();
    _floatController.dispose();
    _workoutViewModel.dispose();
    super.dispose();
  }

  String get _mascotAsset {
    if (_state == _WorkoutState.paused) {
      return 'assets/images/mascot_rest.png';
    }
    if (_state == _WorkoutState.reportWaiting ||
        _state == _WorkoutState.emergency) {
      return 'assets/images/mascot_default.png';
    }
    return _activeMascotAssets[_mascotFrameIndex];
  }

  void _syncMascotAnimation() {
    _mascotFrameTimer?.cancel();
    _mascotFrameTimer = null;

    if (_state != _WorkoutState.running) {
      return;
    }

    _mascotFrameTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (!mounted || _state != _WorkoutState.running) {
        return;
      }
      setState(() {
        _mascotFrameIndex = (_mascotFrameIndex + 1) % _activeMascotAssets.length;
      });
    });
  }

  void _togglePause() {
    if (AppRuntimeFlags.uiPreviewMode) {
      if (_state == _WorkoutState.reportWaiting ||
          _state == _WorkoutState.emergency) {
        return;
      }
      setState(() {
        _state = _state == _WorkoutState.paused
            ? _WorkoutState.running
            : _WorkoutState.paused;
      });
      _syncMascotAnimation();
      return;
    }

    try {
      if (_state == _WorkoutState.paused) {
        _workoutViewModel.resumeWorkout();
      } else {
        _workoutViewModel.pauseWorkout();
      }
    } catch (_) {}
    setState(() {
      _state =
          _state == _WorkoutState.paused ? _WorkoutState.running : _WorkoutState.paused;
    });
    _syncMascotAnimation();
  }

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

  String get _stateLabel {
    switch (_state) {
      case _WorkoutState.running:
        return '운동 중';
      case _WorkoutState.paused:
        return '일시정지';
      case _WorkoutState.resting:
        return '휴식 중';
      case _WorkoutState.reportWaiting:
        return '리포트 준비';
      case _WorkoutState.emergency:
        return '안전 중단';
    }
  }

  String get _headline {
    switch (_state) {
      case _WorkoutState.running:
        return '오늘도 잘하고 있어요';
      case _WorkoutState.paused:
        return '잠깐 쉬어가도 괜찮아요';
      case _WorkoutState.resting:
        return '호흡을 고르고 있어요';
      case _WorkoutState.reportWaiting:
        return '리포트를 준비하고 있어요';
      case _WorkoutState.emergency:
        return '운동을 안전하게 중단했어요';
    }
  }

  String get _cheerMessage {
    switch (_state) {
      case _WorkoutState.running:
        return '아이모와 모가 옆에서 응원하고 있어요.';
      case _WorkoutState.paused:
        return '준비되면 재개 버튼을 눌러 다시 시작해요.';
      case _WorkoutState.resting:
        return '다음 동작을 위해 천천히 숨을 쉬어보세요.';
      case _WorkoutState.reportWaiting:
        return '운동 기록을 정리하는 중이에요.';
      case _WorkoutState.emergency:
        return '괜찮아요. 안전이 가장 먼저예요.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: AppScaffold(
        scrollable: false,
        horizontalPadding: false,
        safeArea: false,
        body: LayoutBuilder(
          builder: (context, _) {
            return Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/workout_bg.png',
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.card.withValues(alpha: 0.03),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.card.withValues(alpha: 0.28),
                          AppColors.card.withValues(alpha: 0.02),
                          AppColors.card.withValues(alpha: 0.02),
                          AppColors.card.withValues(alpha: 0.42),
                        ],
                        stops: const [0, 0.18, 0.68, 1],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 52,
                  left: AppSpacing.screenHorizontal,
                  right: AppSpacing.screenHorizontal,
                  child: _WorkoutCheerCard(
                    mascotAsset: _mascotAsset,
                    floatAnimation: _floatAnimation,
                    headline: _headline,
                    message: _cheerMessage,
                  ),
                ),
                Positioned(
                  left: AppSpacing.screenHorizontal,
                  right: AppSpacing.screenHorizontal,
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  child: _buildControls(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildControls() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: AppColors.heatmapBg.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: _ControlDockButton(
                    label: _state == _WorkoutState.paused ? '재개' : '일시정지',
                    icon: _state == _WorkoutState.paused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    onPressed: _togglePause,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _ControlDockButton(
                    label: '종료',
                    icon: Icons.stop_rounded,
                    danger: true,
                    onPressed: _finishWorkout,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton.icon(
              onPressed: _emergencyStop,
              icon: const Icon(Icons.emergency_rounded, size: 16),
              label: const Text('비상 종료'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
                textStyle: AppTextStyles.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlDockButton extends StatelessWidget {
  const _ControlDockButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final background = danger ? AppColors.error : AppColors.card;
    final foreground = danger ? AppColors.card : AppColors.textPrimary;

    return SizedBox(
      height: 64,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: TextButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          textStyle: AppTextStyles.bodyLg.copyWith(
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
            side: BorderSide(
              color: danger ? AppColors.error : AppColors.border,
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkoutCheerCard extends StatelessWidget {
  const _WorkoutCheerCard({
    required this.mascotAsset,
    required this.floatAnimation,
    required this.headline,
    required this.message,
  });

  final String mascotAsset;
  final Animation<double> floatAnimation;
  final String headline;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          headline,
          textAlign: TextAlign.center,
          style: AppTextStyles.title.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.sm),
        AnimatedBuilder(
          animation: floatAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, floatAnimation.value),
              child: child,
            );
          },
          child: SizedBox(
            width: double.infinity,
            height: 320,
            child: Center(
              child: SizedBox(
                width: 320,
                height: 320,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                  child: Align(
                    key: ValueKey(mascotAsset),
                    alignment: Alignment.center,
                    child: Image.asset(
                      mascotAsset,
                      fit: BoxFit.contain,
                      width: 320,
                      height: 320,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ignore: unused_element
class _ConnectionStatusCard extends StatelessWidget {
  const _ConnectionStatusCard({
    required this.piConnected,
    required this.esp32Connected,
    required this.glassConnected,
  });

  final bool piConnected;
  final bool esp32Connected;
  final bool glassConnected;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      variant: ImoCardVariant.subtle,
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('기기 상태', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              StatusBadge(label: piConnected ? 'Pi connected' : 'Pi waiting', variant: piConnected ? StatusVariant.success : StatusVariant.warning),
              StatusBadge(label: esp32Connected ? 'ESP32 connected' : 'ESP32 waiting', variant: esp32Connected ? StatusVariant.success : StatusVariant.warning),
              StatusBadge(label: glassConnected ? 'Glass ready' : 'Glass waiting', variant: glassConnected ? StatusVariant.info : StatusVariant.warning),
            ],
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _WorkoutNoticeCard extends StatelessWidget {
  const _WorkoutNoticeCard();

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      variant: ImoCardVariant.outlined,
      paddingSize: ImoCardPadding.lg,
      child: Text(
        '현재 화면은 운동 중 UI 스켈레톤입니다. 이후 Pi WebSocket 이벤트로 세트 진행, 일시정지, 재개, 종료, 결과 화면 전환이 연결됩니다.',
        style: AppTextStyles.bodySmall,
      ),
    );
  }
}
