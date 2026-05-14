import 'package:flutter/material.dart';

import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/imo_card.dart';
import '../../core/widgets/status_badge.dart';
import '../model/smartglass_display_models.dart';
import '../view_model/smartglass_display_viewmodel.dart';
import 'smartglass_connection_chip.dart';
import 'smartglass_focus_card.dart';
import 'smartglass_guidance_panel.dart';
import 'smartglass_metrics_strip.dart';

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
  }

  @override
  void dispose() {
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
        return AppScaffold(
          title: 'Smartglass Display',
          child: Container(
            color: AppColors.backgroundSoftGreen,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SmartglassConnectionChip(
                            connectionState: state.connectionState,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          StatusBadge(
                            label: state.phaseLabel,
                            variant: _badgeVariant(state.tone),
                            size: StatusBadgeSize.md,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          StatusBadge(
                            label: state.phaseSummary,
                            variant: StatusVariant.info,
                            size: StatusBadgeSize.md,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          StatusBadge(
                            label: _viewModel.displayModeLabel,
                            variant: _viewModel.usingLiveSnapshot
                                ? StatusVariant.success
                                : StatusVariant.info,
                            size: StatusBadgeSize.md,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      SmartglassMetricsStrip(
                        workoutLabel: state.workoutLabel,
                        repCount: state.repCount,
                        targetRep: state.targetRep,
                        setProgressLabel: state.setProgressLabel,
                        paceLabel: state.paceLabel,
                        activationPercent: state.activationPercent,
                        activationLabel: state.activationLabel,
                        restSeconds: state.restSeconds,
                        connectionSummary: _connectionSummary(state),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stacked = constraints.maxWidth < 920;
                          if (stacked) {
                            return Column(
                              children: [
                                SmartglassFocusCard(
                                  previewLabel: state.previewLabel,
                                  phaseSummary: state.phaseSummary,
                                  phaseLabel: state.phaseLabel,
                                  poseTitle: state.poseTitle,
                                  poseDetail: state.poseDetail,
                                  primaryMessage: state.primaryMessage,
                                  secondaryMessage: state.secondaryMessage,
                                  focusProgress: state.focusProgress,
                                  focusProgressLabel: state.focusProgressLabel,
                                  reconnectHint: state.reconnectHint,
                                  tone: state.tone,
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                _SideInfoCard(state: state),
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: SmartglassFocusCard(
                                  previewLabel: state.previewLabel,
                                  phaseSummary: state.phaseSummary,
                                  phaseLabel: state.phaseLabel,
                                  poseTitle: state.poseTitle,
                                  poseDetail: state.poseDetail,
                                  primaryMessage: state.primaryMessage,
                                  secondaryMessage: state.secondaryMessage,
                                  focusProgress: state.focusProgress,
                                  focusProgressLabel: state.focusProgressLabel,
                                  reconnectHint: state.reconnectHint,
                                  tone: state.tone,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.lg),
                              Expanded(
                                flex: 2,
                                child: _SideInfoCard(state: state),
                              ),
                            ],
                          );
                        },
                      ),
                      if (widget.showPreviewPanel) ...[
                        const SizedBox(height: AppSpacing.xl),
                        ImoCard(
                          variant: ImoCardVariant.outlined,
                          paddingSize: ImoCardPadding.md,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Preview Scenario',
                                style: AppTextStyles.sectionTitle,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                '기존 router/dependencies를 건드리지 않고 스마트글래스 전용 UI를 독립 검증하기 위한 mock 패널입니다.',
                                style: AppTextStyles.bodySmall,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                '가로 화면 우선 레이아웃과 중간 연결 복구 시나리오를 함께 검증합니다. 실제 세션 상태가 들어오면 이 패널 대신 snapshot 적용이 중심이 됩니다.',
                                style: AppTextStyles.bodySmall,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.sm,
                                children: [
                                  FilledButton(
                                    onPressed: _viewModel.isMockPlaybackRunning
                                        ? null
                                        : _viewModel.replayMockPlayback,
                                    child: const Text('Live Demo 재생'),
                                  ),
                                  OutlinedButton(
                                    onPressed: _viewModel.isMockPlaybackRunning
                                        ? _viewModel.stopMockPlayback
                                        : null,
                                    child: const Text('재생 중지'),
                                  ),
                                  OutlinedButton(
                                    onPressed: () {
                                      _viewModel.stopMockPlayback(resetIndex: true);
                                      _viewModel.selectScenario(
                                        SmartglassPreviewScenario.waiting,
                                      );
                                    },
                                    child: const Text('Preview 초기화'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Live Demo 재생은 mock Pi 메시지 시퀀스를 `applyPiMessageEnvelope()` 경로로 흘려보내 실제 연동과 동일한 변환 경로를 검증합니다.',
                                style: AppTextStyles.bodySmall,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.sm,
                                children: _viewModel.previewScenarios.map((
                                  scenario,
                                ) {
                                  final selected =
                                      _viewModel.scenario == scenario;
                                  return ChoiceChip(
                                    label: Text(
                                      _viewModel.scenarioLabel(scenario),
                                    ),
                                    selected: selected,
                                    onSelected: (_) =>
                                        _viewModel.selectScenario(scenario),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  StatusVariant _badgeVariant(SmartglassDisplayTone tone) {
    switch (tone) {
      case SmartglassDisplayTone.good:
        return StatusVariant.success;
      case SmartglassDisplayTone.warn:
        return StatusVariant.warning;
      case SmartglassDisplayTone.danger:
        return StatusVariant.error;
      case SmartglassDisplayTone.neutral:
        return StatusVariant.info;
    }
  }

  String _connectionSummary(SmartglassDisplayState state) {
    late final String connectionLabel;
    switch (state.connectionState) {
      case SmartglassConnectionState.connected:
        connectionLabel = '연결 안정';
      case SmartglassConnectionState.connecting:
        connectionLabel = '연결 준비';
      case SmartglassConnectionState.disconnected:
        connectionLabel = '연결 끊김';
    }

    return '$connectionLabel · ${state.sourceLabel}';
  }
}

class _SideInfoCard extends StatelessWidget {
  const _SideInfoCard({required this.state});

  final SmartglassDisplayState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ImoCard(
          paddingSize: ImoCardPadding.md,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('센서 배치', style: AppTextStyles.sectionTitle),
              const SizedBox(height: AppSpacing.sm),
              ...state.sensorPlacements.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Icon(
                          Icons.radio_button_checked,
                          size: 10,
                          color: AppColors.primaryStrong,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(item, style: AppTextStyles.body),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SmartglassGuidancePanel(state: state),
      ],
    );
  }
}
