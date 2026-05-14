import 'package:flutter/material.dart';

enum SmartglassConnectionState { connected, connecting, disconnected }

enum SmartglassDisplayTone { neutral, good, warn, danger }

enum SmartglassSessionPhase {
  waitingWorkoutSelection,
  planReady,
  sensorAttachmentPending,
  calibrationReady,
  calibrating,
  calibrationSuccess,
  workoutActive,
  resting,
  workoutCompleted,
}

enum SmartglassPreviewScenario {
  waiting,
  planReady,
  sensorAttachment,
  calibrationReady,
  calibrating,
  calibrationDone,
  activeBalanced,
  activeFast,
  activeImbalance,
  resting,
  workoutCompleted,
}

class SmartglassCoachCue {
  const SmartglassCoachCue({
    required this.label,
    required this.detail,
    this.tone = SmartglassDisplayTone.neutral,
  });

  final String label;
  final String detail;
  final SmartglassDisplayTone tone;
}

class SmartglassDisplayState {
  const SmartglassDisplayState({
    required this.connectionState,
    required this.sessionPhase,
    required this.previewLabel,
    required this.phaseLabel,
    required this.workoutLabel,
    required this.repCount,
    required this.targetRep,
    required this.currentSet,
    required this.totalSets,
    required this.paceLabel,
    required this.activationPercent,
    required this.activationLabel,
    required this.poseTitle,
    required this.poseDetail,
    required this.primaryMessage,
    required this.secondaryMessage,
    required this.restSeconds,
    required this.calibrationProgress,
    required this.sensorPlacements,
    required this.statusHighlights,
    required this.coachCues,
    required this.readinessLabel,
    required this.readinessDetail,
    required this.reconnectHint,
    required this.sourceLabel,
    required this.tone,
  });

  final SmartglassConnectionState connectionState;
  final SmartglassSessionPhase sessionPhase;
  final String previewLabel;
  final String phaseLabel;
  final String workoutLabel;
  final int repCount;
  final int targetRep;
  final int currentSet;
  final int totalSets;
  final String paceLabel;
  final int activationPercent;
  final String activationLabel;
  final String poseTitle;
  final String poseDetail;
  final String primaryMessage;
  final String secondaryMessage;
  final int restSeconds;
  final double calibrationProgress;
  final List<String> sensorPlacements;
  final List<String> statusHighlights;
  final List<SmartglassCoachCue> coachCues;
  final String readinessLabel;
  final String readinessDetail;
  final String reconnectHint;
  final String sourceLabel;
  final SmartglassDisplayTone tone;

  bool get isWaiting =>
      sessionPhase == SmartglassSessionPhase.waitingWorkoutSelection;
  bool get isResting => sessionPhase == SmartglassSessionPhase.resting;
  bool get isCalibrating =>
      sessionPhase == SmartglassSessionPhase.calibrating;

  String get setProgressLabel {
    if (currentSet == 0 || totalSets == 0) {
      return '세트 준비 대기';
    }

    return '$currentSet / $totalSets 세트';
  }

  double get repProgress {
    if (targetRep <= 0) return 0;
    return (repCount / targetRep).clamp(0, 1).toDouble();
  }

  double get activationRatio =>
      (activationPercent / 100).clamp(0, 1).toDouble();

  double get focusProgress {
    if (isCalibrating) {
      return calibrationProgress.clamp(0, 1);
    }

    return repProgress;
  }

  String get focusProgressLabel {
    if (isCalibrating) {
      return '캘리브레이션 ${(calibrationProgress * 100).round()}%';
    }

    if (targetRep <= 0) {
      return '진행률 대기';
    }

    return '반복 진행 ${(repProgress * 100).round()}%';
  }

  String get phaseSummary {
    switch (sessionPhase) {
      case SmartglassSessionPhase.waitingWorkoutSelection:
        return '운동 선택 전';
      case SmartglassSessionPhase.planReady:
        return '운동 계획 확정';
      case SmartglassSessionPhase.sensorAttachmentPending:
        return '센서 부착 단계';
      case SmartglassSessionPhase.calibrationReady:
        return '캘리브레이션 시작 가능';
      case SmartglassSessionPhase.calibrating:
        return '캘리브레이션 진행 중';
      case SmartglassSessionPhase.calibrationSuccess:
        return '캘리브레이션 완료';
      case SmartglassSessionPhase.workoutActive:
        return '운동 진행 중';
      case SmartglassSessionPhase.resting:
        return '세트 간 휴식';
      case SmartglassSessionPhase.workoutCompleted:
        return '운동 종료';
    }
  }
}

Color smartglassToneColor(
  SmartglassDisplayTone tone, {
  required Color neutral,
  required Color good,
  required Color warn,
  required Color danger,
}) {
  switch (tone) {
    case SmartglassDisplayTone.good:
      return good;
    case SmartglassDisplayTone.warn:
      return warn;
    case SmartglassDisplayTone.danger:
      return danger;
    case SmartglassDisplayTone.neutral:
      return neutral;
  }
}
