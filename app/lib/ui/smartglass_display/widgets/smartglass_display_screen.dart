import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    _viewModel = widget.viewModel ?? SmartglassDisplayViewModel();
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        final state = _viewModel.state;
        final waitingMode = state.isWaiting;

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
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 1180;
                      if (compact) {
                        return _CompactHudLayout(
                          state: state,
                          viewModel: _viewModel,
                          showPreviewPanel: widget.showPreviewPanel,
                          waitingMode: waitingMode,
                        );
                      }

                      return _LandscapeHudLayout(
                        state: state,
                        viewModel: _viewModel,
                        showPreviewPanel: widget.showPreviewPanel,
                        waitingMode: waitingMode,
                      );
                    },
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

class _LandscapeHudLayout extends StatelessWidget {
  const _LandscapeHudLayout({
    required this.state,
    required this.viewModel,
    required this.showPreviewPanel,
    required this.waitingMode,
  });

  final SmartglassDisplayState state;
  final SmartglassDisplayViewModel viewModel;
  final bool showPreviewPanel;
  final bool waitingMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 10,
                child: Column(
                  children: [
                    Expanded(
                      flex: 24,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 9,
                            child: _WorkoutPanel(state: state),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            flex: 23,
                            child: _TopKpiStrip(state: state, viewModel: viewModel),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Expanded(
                      flex: waitingMode ? 41 : 39,
                      child: _CenterHudCard(state: state),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Expanded(
                      flex: 18,
                      child: _FooterStrip(state: state),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    Expanded(
                      flex: waitingMode ? 19 : 17,
                      child: _ActivationPanel(state: state),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Expanded(
                      flex: 16,
                      child: _SensorPlacementPanel(state: state),
                    ),
                    if (showPreviewPanel) ...[
                      const SizedBox(height: AppSpacing.md),
                      Expanded(
                        flex: 12,
                        child: _ControlPanel(viewModel: viewModel),
                      ),
                    ],
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

class _CompactHudLayout extends StatelessWidget {
  const _CompactHudLayout({
    required this.state,
    required this.viewModel,
    required this.showPreviewPanel,
    required this.waitingMode,
  });

  final SmartglassDisplayState state;
  final SmartglassDisplayViewModel viewModel;
  final bool showPreviewPanel;
  final bool waitingMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 8,
                child: Column(
                  children: [
                    Expanded(flex: 22, child: _WorkoutPanel(state: state)),
                    const SizedBox(height: AppSpacing.md),
                    Expanded(flex: 46, child: _CenterHudCard(state: state)),
                    const SizedBox(height: AppSpacing.md),
                    Expanded(flex: 18, child: _FooterStrip(state: state)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 10,
                child: Column(
                  children: [
                    Expanded(
                      flex: 22,
                      child: _TopKpiStrip(state: state, viewModel: viewModel),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Expanded(flex: 18, child: _ActivationPanel(state: state)),
                    const SizedBox(height: AppSpacing.md),
                    Expanded(flex: 18, child: _SensorPlacementPanel(state: state)),
                    if (showPreviewPanel) ...[
                      const SizedBox(height: AppSpacing.md),
                      Expanded(flex: 12, child: _ControlPanel(viewModel: viewModel)),
                    ],
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
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF071118),
                Color(0xFF02070A),
              ],
            ),
          ),
        ),
        CustomPaint(painter: _GridPainter()),
        Center(
          child: IgnorePointer(
            child: Container(
              width: 520,
              height: 520,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x1470E8CD)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0C70E8CD),
                    blurRadius: 0,
                    spreadRadius: 28,
                  ),
                  BoxShadow(
                    color: Color(0x0870E8CD),
                    blurRadius: 0,
                    spreadRadius: 72,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 52.0;
    final linePaint = Paint()
      ..color = const Color(0x0A70E8CD)
      ..strokeWidth = 1;

    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HudPanel extends StatelessWidget {
  const _HudPanel({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x3870E8CD)),
        color: const Color(0xC90A141A),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class _HudEyebrow extends StatelessWidget {
  const _HudEyebrow(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.caption.copyWith(
        color: const Color(0xFF9FC7BD),
        letterSpacing: 2.2,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _WorkoutPanel extends StatelessWidget {
  const _WorkoutPanel({required this.state});

  final SmartglassDisplayState state;

  @override
  Widget build(BuildContext context) {
    return _HudPanel(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HudEyebrow('WORKOUT FOCUS'),
          const SizedBox(height: AppSpacing.md),
          Text(
            state.workoutLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.display.copyWith(
              fontSize: state.isWaiting ? 42 : 36,
              color: const Color(0xFFF1FFF9),
              height: 0.95,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _PhaseChip(
            label: state.phaseLabel,
            color: _toneColor(state.tone),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: Text(
              state.secondaryMessage,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                color: const Color(0xFF9FC7BD),
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopKpiStrip extends StatelessWidget {
  const _TopKpiStrip({
    required this.state,
    required this.viewModel,
  });

  final SmartglassDisplayState state;
  final SmartglassDisplayViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 12,
          child: _KpiCard(
            eyebrow: 'REP COUNT',
            value: state.targetRep > 0 ? '${state.repCount}' : '-',
            secondary: state.targetRep > 0 ? 'target ${state.targetRep}' : 'target -',
            footer: state.setProgressLabel,
            accentColor: const Color(0xFFF4CC72),
            large: true,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 9,
          child: _KpiCard(
            eyebrow: 'CURRENT PACE',
            value: state.paceLabel,
            secondary: state.phaseSummary,
            footer: state.statusHighlights.isNotEmpty
                ? state.statusHighlights.first
                : '반복 속도 분석',
            accentColor: _paceColor(state.paceLabel),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 9,
          child: _ActivationKpi(state: state),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 10,
          child: _StatusKpi(
            state: state,
            displayModeLabel: viewModel.displayModeLabel,
            usingLiveSnapshot: viewModel.usingLiveSnapshot,
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.eyebrow,
    required this.value,
    required this.secondary,
    required this.footer,
    required this.accentColor,
    this.large = false,
  });

  final String eyebrow;
  final String value;
  final String secondary;
  final String footer;
  final Color accentColor;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return _HudPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HudEyebrow(eyebrow),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.metric.copyWith(
              fontSize: large ? 82 : 46,
              color: accentColor,
              height: 0.95,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            secondary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.label.copyWith(
              color: const Color(0xFFF1FFF9),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            footer,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              color: const Color(0xFF9FC7BD),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivationKpi extends StatelessWidget {
  const _ActivationKpi({required this.state});

  final SmartglassDisplayState state;

  @override
  Widget build(BuildContext context) {
    return _HudPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HudEyebrow('ACTIVATION'),
          const Spacer(),
          Text(
            '${state.activationPercent}%',
            style: AppTextStyles.metric.copyWith(
              fontSize: 46,
              color: const Color(0xFFF1FFF9),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
            child: LinearProgressIndicator(
              minHeight: 14,
              value: state.activationRatio,
              color: const Color(0xFF70E8CD),
              backgroundColor: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            state.activationLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              color: const Color(0xFF9FC7BD),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusKpi extends StatelessWidget {
  const _StatusKpi({
    required this.state,
    required this.displayModeLabel,
    required this.usingLiveSnapshot,
  });

  final SmartglassDisplayState state;
  final String displayModeLabel;
  final bool usingLiveSnapshot;

  @override
  Widget build(BuildContext context) {
    final statusColor = usingLiveSnapshot
        ? const Color(0xFF7BFFB2)
        : const Color(0xFF70E8CD);

    return _HudPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HudEyebrow('GLASS STATUS'),
          const Spacer(),
          Text(
            state.connectionState == SmartglassConnectionState.connected
                ? '연결 안정'
                : state.connectionState == SmartglassConnectionState.connecting
                    ? '연결 준비'
                    : '연결 끊김',
            style: AppTextStyles.metric.copyWith(
              fontSize: 34,
              color: statusColor,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            displayModeLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.label.copyWith(
              color: const Color(0xFFF1FFF9),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            state.sourceLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              color: const Color(0xFF9FC7BD),
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterHudCard extends StatelessWidget {
  const _CenterHudCard({required this.state});

  final SmartglassDisplayState state;

  @override
  Widget build(BuildContext context) {
    final toneColor = _toneColor(state.tone);

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          _Ring(sizeFactor: 0.96),
          _Ring(sizeFactor: 0.74),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 420),
            child: _HudPanel(
              padding: const EdgeInsets.symmetric(
                horizontal: 30,
                vertical: 28,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _PhaseChip(
                    label: state.phaseSummary,
                    color: toneColor,
                    dense: true,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    state.poseTitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.display.copyWith(
                      fontSize: state.isWaiting ? 54 : 42,
                      color: const Color(0xFFF1FFF9),
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    state.poseDetail,
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyLg.copyWith(
                      color: const Color(0xFF9FC7BD),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
                    child: LinearProgressIndicator(
                      minHeight: 10,
                      value: state.focusProgress,
                      color: toneColor,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    state.focusProgressLabel,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: toneColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.sizeFactor});

  final double sizeFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: sizeFactor,
      heightFactor: sizeFactor,
      child: AspectRatio(
        aspectRatio: 1,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x2470E8CD)),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivationPanel extends StatelessWidget {
  const _ActivationPanel({required this.state});

  final SmartglassDisplayState state;

  @override
  Widget build(BuildContext context) {
    return _HudPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HudEyebrow('MUSCLE FEEDBACK'),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${state.activationPercent}%',
            style: AppTextStyles.metric.copyWith(
              fontSize: 42,
              color: const Color(0xFFF1FFF9),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
            child: LinearProgressIndicator(
              minHeight: 14,
              value: state.activationRatio,
              color: const Color(0xFF70E8CD),
              backgroundColor: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: Text(
              state.primaryMessage,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                color: const Color(0xFFF1FFF9),
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SensorPlacementPanel extends StatelessWidget {
  const _SensorPlacementPanel({required this.state});

  final SmartglassDisplayState state;

  @override
  Widget build(BuildContext context) {
    return _HudPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HudEyebrow('SENSOR PLACEMENT'),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: Column(
              children: state.sensorPlacements.take(4).map((item) {
                final parts = item.split(' ');
                final name = parts.first;
                final position = parts.length > 1 ? parts.sublist(1).join(' ') : '-';
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: const Color(0xFFF1FFF9),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            position,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: AppTextStyles.caption.copyWith(
                              color: const Color(0xFF9FC7BD),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterStrip extends StatelessWidget {
  const _FooterStrip({required this.state});

  final SmartglassDisplayState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 12,
          child: _FooterCard(
            eyebrow: 'SUMMARY',
            title: state.readinessLabel,
            note: state.readinessDetail,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 10,
          child: _FooterCard(
            eyebrow: 'BALANCE',
            title: state.statusHighlights.length > 1
                ? state.statusHighlights[1]
                : state.poseTitle,
            note: state.coachCues.isNotEmpty
                ? state.coachCues.first.detail
                : state.poseDetail,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 10,
          child: _FooterCard(
            eyebrow: 'TIMING',
            title: state.isResting
                ? '휴식 ${state.restSeconds}초'
                : state.setProgressLabel,
            note: state.reconnectHint,
          ),
        ),
      ],
    );
  }
}

class _FooterCard extends StatelessWidget {
  const _FooterCard({
    required this.eyebrow,
    required this.title,
    required this.note,
  });

  final String eyebrow;
  final String title;
  final String note;

  @override
  Widget build(BuildContext context) {
    return _HudPanel(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HudEyebrow(eyebrow),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.sectionTitle.copyWith(
              color: const Color(0xFFF1FFF9),
              fontSize: 22,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: Text(
              note,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(
                color: const Color(0xFF9FC7BD),
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({required this.viewModel});

  final SmartglassDisplayViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return _HudPanel(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HudEyebrow('DISPLAY CONTROL'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _MiniActionButton(
                label: 'Live Demo',
                onTap: viewModel.isMockPlaybackRunning
                    ? null
                    : viewModel.replayMockPlayback,
                filled: true,
              ),
              _MiniActionButton(
                label: 'Stop',
                onTap: viewModel.isMockPlaybackRunning
                    ? viewModel.stopMockPlayback
                    : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: viewModel.previewScenarios.take(6).map((scenario) {
                final selected = !viewModel.usingLiveSnapshot &&
                    viewModel.scenario == scenario;
                return ChoiceChip(
                  label: Text(
                    viewModel.scenarioLabel(scenario),
                    style: AppTextStyles.caption.copyWith(
                      color: selected
                          ? const Color(0xFF041014)
                          : const Color(0xFF9FC7BD),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  selected: selected,
                  onSelected: (_) => viewModel.selectScenario(scenario),
                  selectedColor: const Color(0xFF70E8CD),
                  backgroundColor: Colors.white.withValues(alpha: 0.04),
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: selected ? 0 : 0.1),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  const _MiniActionButton({
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final background = filled
        ? (enabled ? const Color(0xFF70E8CD) : Colors.white.withValues(alpha: 0.08))
        : Colors.white.withValues(alpha: 0.04);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
      child: Ink(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
          border: Border.all(
            color: filled
                ? Colors.transparent
                : Colors.white.withValues(alpha: enabled ? 0.14 : 0.06),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: filled
                ? const Color(0xFF041014)
                : (enabled ? const Color(0xFFF1FFF9) : const Color(0xFF5E7D75)),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PhaseChip extends StatelessWidget {
  const _PhaseChip({
    required this.label,
    required this.color,
    this.dense = false,
  });

  final String label;
  final Color color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.sm : 14,
        vertical: dense ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
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

Color _paceColor(String paceLabel) {
  switch (paceLabel) {
    case '빠름':
      return const Color(0xFFFFD37F);
    case '느림':
      return const Color(0xFFFF886F);
    case '적정':
      return const Color(0xFF7BFFB2);
    default:
      return const Color(0xFFF1FFF9);
  }
}
