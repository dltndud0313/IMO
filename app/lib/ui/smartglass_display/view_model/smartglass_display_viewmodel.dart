import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/services/pi_message.dart';
import '../../../data/services/pi_socket_service.dart';
import '../../../domain/models/workout_session.dart';
import '../data/smartglass_mock_live_messages.dart';
import '../data/smartglass_pi_snapshot_adapter.dart';
import '../data/smartglass_preview_scenarios.dart';
import '../data/smartglass_session_snapshot_mapper.dart';
import '../model/smartglass_display_models.dart';
import '../model/smartglass_session_snapshot.dart';

class SmartglassDisplayViewModel extends ChangeNotifier {
  SmartglassDisplayViewModel({
    SmartglassPreviewScenario initialScenario =
        SmartglassPreviewScenario.waiting,
    SmartglassSessionSnapshotMapper? snapshotMapper,
    SmartglassPiSnapshotAdapter? snapshotAdapter,
    PiSocketService? piSocketService,
  })  : _scenario = initialScenario,
        _snapshotMapper =
            snapshotMapper ?? const SmartglassSessionSnapshotMapper(),
        _snapshotAdapter = snapshotAdapter ?? const SmartglassPiSnapshotAdapter(),
        _piSocketService = piSocketService,
        _state = SmartglassPreviewScenarios.build(initialScenario);

  SmartglassPreviewScenario _scenario;
  SmartglassDisplayState _state;
  final SmartglassSessionSnapshotMapper _snapshotMapper;
  final SmartglassPiSnapshotAdapter _snapshotAdapter;
  final PiSocketService? _piSocketService;
  StreamSubscription<PiMessage>? _piSubscription;
  StreamSubscription<PiSocketConnectionState>? _connectionSubscription;
  bool _usingLiveSnapshot = false;
  bool _paused = false;
  bool _awaitingSessionResult = false;
  bool _emergencyStopped = false;
  WorkoutSession? _completedSession;
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
  bool get isConnected => _piSocketService?.isConnected ?? false;
  bool get paused => _paused;
  bool get awaitingSessionResult => _awaitingSessionResult;
  bool get emergencyStopped => _emergencyStopped;
  bool get controlsLocked => _awaitingSessionResult || _completedSession != null;
  WorkoutSession? get completedSession => _completedSession;

  void selectScenario(SmartglassPreviewScenario scenario) {
    if (_scenario == scenario) return;
    stopMockPlayback();
    _scenario = scenario;
    _usingLiveSnapshot = false;
    _state = SmartglassPreviewScenarios.build(scenario);
    notifyListeners();
  }

  Future<void> startListeningToPi() async {
    final socket = _piSocketService;
    if (socket == null) return;

    await _connectionSubscription?.cancel();
    _connectionSubscription = socket.connectionState.listen((_) {
      notifyListeners();
    });

    try {
      await socket.connect();
    } catch (_) {
      notifyListeners();
      return;
    }

    await _piSubscription?.cancel();
    _piSubscription = socket.messages.listen(_handlePiMessage);
    notifyListeners();
  }

  Future<bool> togglePause() async {
    final socket = _piSocketService;
    if (socket == null || !socket.isConnected || controlsLocked) {
      return false;
    }

    if (_paused) {
      socket.resumeWorkout();
      _paused = false;
    } else {
      socket.pauseWorkout();
      _paused = true;
    }
    notifyListeners();
    return true;
  }

  Future<bool> stopWorkout() async {
    final socket = _piSocketService;
    if (socket == null || !socket.isConnected || controlsLocked) {
      return false;
    }

    socket.stopWorkout();
    _paused = false;
    _awaitingSessionResult = true;
    _emergencyStopped = false;
    notifyListeners();
    return true;
  }

  Future<bool> emergencyStop() async {
    final socket = _piSocketService;
    if (socket == null || !socket.isConnected || controlsLocked) {
      return false;
    }

    socket.emergencyStop();
    _paused = false;
    _awaitingSessionResult = true;
    _emergencyStopped = true;
    notifyListeners();
    return true;
  }

  void applySessionSnapshot(SmartglassSessionSnapshot snapshot) {
    _usingLiveSnapshot = true;
    _state = _snapshotMapper.map(snapshot);
    notifyListeners();
  }

  bool applyPiMessageEnvelope(
    Map<String, dynamic> message, {
    bool notify = true,
  }) {
    final snapshot = _snapshotAdapter.tryParse(message);
    if (snapshot == null) {
      return false;
    }

    _usingLiveSnapshot = true;
    _state = _snapshotMapper.map(snapshot);
    if (notify) {
      notifyListeners();
    }
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

  void _handlePiMessage(PiMessage message) {
    var shouldNotify = applyPiMessageEnvelope(message.toJson(), notify: false);

    if (message is WorkoutPausedMessage) {
      shouldNotify = _setPauseState(true) || shouldNotify;
    } else if (message is WorkoutResumedMessage) {
      shouldNotify = _setPauseState(false) || shouldNotify;
      if (_emergencyStopped) {
        _emergencyStopped = false;
        shouldNotify = true;
      }
    } else if (message is WorkoutStartedMessage) {
      shouldNotify = _resetWorkoutControlState() || shouldNotify;
    } else if (message is WorkoutCompletedMessage) {
      if (_paused) {
        _paused = false;
        shouldNotify = true;
      }
      if (!_awaitingSessionResult) {
        _awaitingSessionResult = true;
        shouldNotify = true;
      }
      final isEmergency =
          message.status == 'emergency_stopped' ||
          message.endReason == 'emergency_stop';
      if (_emergencyStopped != isEmergency) {
        _emergencyStopped = isEmergency;
        shouldNotify = true;
      }
    } else if (message is SessionResultMessage) {
      if (_paused) {
        _paused = false;
        shouldNotify = true;
      }
      if (_awaitingSessionResult) {
        _awaitingSessionResult = false;
        shouldNotify = true;
      }
      final isEmergency = message.session.status == 'emergency_stopped';
      if (_emergencyStopped != isEmergency) {
        _emergencyStopped = isEmergency;
        shouldNotify = true;
      }
      if (_completedSession != message.session) {
        _completedSession = message.session;
        shouldNotify = true;
      }
    }

    if (shouldNotify) {
      notifyListeners();
    }
  }

  bool _setPauseState(bool value) {
    if (_paused == value) {
      return false;
    }
    _paused = value;
    return true;
  }

  bool _resetWorkoutControlState() {
    final changed =
        _paused || _awaitingSessionResult || _emergencyStopped || _completedSession != null;
    _paused = false;
    _awaitingSessionResult = false;
    _emergencyStopped = false;
    _completedSession = null;
    return changed;
  }

  @override
  void dispose() {
    _piSubscription?.cancel();
    _piSubscription = null;
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _mockPlaybackTimer?.cancel();
    super.dispose();
  }
}
