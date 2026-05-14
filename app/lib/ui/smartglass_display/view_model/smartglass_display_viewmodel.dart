import 'dart:async';

import 'package:flutter/material.dart';

import '../data/smartglass_mock_live_messages.dart';
import '../data/smartglass_preview_scenarios.dart';
import '../data/smartglass_pi_snapshot_adapter.dart';
import '../data/smartglass_session_snapshot_mapper.dart';
import '../model/smartglass_display_models.dart';
import '../model/smartglass_session_snapshot.dart';

class SmartglassDisplayViewModel extends ChangeNotifier {
  SmartglassDisplayViewModel({
    SmartglassPreviewScenario initialScenario =
        SmartglassPreviewScenario.waiting,
    SmartglassSessionSnapshotMapper? snapshotMapper,
    SmartglassPiSnapshotAdapter? snapshotAdapter,
  }) : _scenario = initialScenario,
       _snapshotMapper = snapshotMapper ?? const SmartglassSessionSnapshotMapper(),
       _snapshotAdapter = snapshotAdapter ?? const SmartglassPiSnapshotAdapter(),
       _state = SmartglassPreviewScenarios.build(initialScenario);

  SmartglassPreviewScenario _scenario;
  SmartglassDisplayState _state;
  final SmartglassSessionSnapshotMapper _snapshotMapper;
  final SmartglassPiSnapshotAdapter _snapshotAdapter;
  bool _usingLiveSnapshot = false;
  Timer? _mockPlaybackTimer;
  int _mockPlaybackIndex = 0;

  SmartglassPreviewScenario get scenario => _scenario;
  SmartglassDisplayState get state => _state;
  List<SmartglassPreviewScenario> get previewScenarios =>
      SmartglassPreviewScenario.values;
  bool get usingLiveSnapshot => _usingLiveSnapshot;
  bool get isMockPlaybackRunning => _mockPlaybackTimer?.isActive ?? false;
  String get displayModeLabel =>
      _usingLiveSnapshot ? 'Live Snapshot Mode' : 'Preview Mode';

  void selectScenario(SmartglassPreviewScenario scenario) {
    if (_scenario == scenario) return;
    stopMockPlayback();
    _scenario = scenario;
    _usingLiveSnapshot = false;
    _state = SmartglassPreviewScenarios.build(scenario);
    notifyListeners();
  }

  void applySessionSnapshot(SmartglassSessionSnapshot snapshot) {
    _usingLiveSnapshot = true;
    _state = _snapshotMapper.map(snapshot);
    notifyListeners();
  }

  bool applyPiMessageEnvelope(Map<String, dynamic> message) {
    final snapshot = _snapshotAdapter.tryParse(message);
    if (snapshot == null) {
      return false;
    }

    applySessionSnapshot(snapshot);
    return true;
  }

  String scenarioLabel(SmartglassPreviewScenario scenario) {
    return SmartglassPreviewScenarios.labelOf(scenario);
  }

  void startMockPlayback({Duration stepDuration = const Duration(seconds: 2)}) {
    stopMockPlayback(resetIndex: false);

    final sequence = SmartglassMockLiveMessages.buildSequence();
    if (_mockPlaybackIndex >= sequence.length) {
      _mockPlaybackIndex = 0;
    }

    applyPiMessageEnvelope(sequence[_mockPlaybackIndex]);
    _mockPlaybackIndex += 1;
    notifyListeners();

    _mockPlaybackTimer = Timer.periodic(stepDuration, (_) {
      if (_mockPlaybackIndex >= sequence.length) {
        stopMockPlayback(resetIndex: true);
        return;
      }

      applyPiMessageEnvelope(sequence[_mockPlaybackIndex]);
      _mockPlaybackIndex += 1;
      notifyListeners();
    });
    notifyListeners();
  }

  void stopMockPlayback({bool resetIndex = false}) {
    _mockPlaybackTimer?.cancel();
    _mockPlaybackTimer = null;
    if (resetIndex) {
      _mockPlaybackIndex = 0;
    }
    notifyListeners();
  }

  void replayMockPlayback() {
    _mockPlaybackIndex = 0;
    startMockPlayback();
  }

  @override
  void dispose() {
    _mockPlaybackTimer?.cancel();
    super.dispose();
  }
}
