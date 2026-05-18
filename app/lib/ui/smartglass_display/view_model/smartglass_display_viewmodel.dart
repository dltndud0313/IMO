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
  // EMG 1~4 채널값은 glass_display_data 에만 실리므로, 그 외 메시지에서
  // 화면이 비지 않도록 마지막으로 받은 채널값을 유지한다.
  List<int?> _lastEmgChannelPercents = const [];
  // glass_display_data 는 ~50Hz 로 들어오므로 알림을 ~12.5Hz 로 제한한다.
  static const _liveNotifyInterval = Duration(milliseconds: 80);
  Timer? _liveNotifyTimer;
  bool _liveNotifyPending = false;

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
    _lastEmgChannelPercents = const [];
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
    if (controlsLocked) return false;
    final socket = _piSocketService;
    final connected = socket?.isConnected ?? false;

    // Pi 연결이 살아있으면 명령 송신, 끊겼으면 로컬 UI 상태만 토글 (시각용).
    if (_paused) {
      if (connected) socket!.resumeWorkout();
      _paused = false;
    } else {
      if (connected) socket!.pauseWorkout();
      _paused = true;
    }
    notifyListeners();
    return true;
  }

  Future<bool> stopWorkout() async {
    if (controlsLocked) return false;
    final socket = _piSocketService;
    final connected = socket?.isConnected ?? false;

    // Pi 끊긴 상태에서 누른 중지는 emergency stop 으로 처리해서 강제로
    // 결과 화면으로 빠질 수 있게 한다 (화면 측 timeout 이 statusFallback 으로 라우팅).
    if (connected) socket!.stopWorkout();
    _paused = false;
    _awaitingSessionResult = true;
    _emergencyStopped = !connected;
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
    final parsed = _snapshotAdapter.tryParse(message);
    if (parsed == null) {
      return false;
    }

    // 채널 활성도(EMG 1~4)는 glass_display_data 메시지에만 실린다.
    // 그 외 메시지(rest_started 등)는 직전 채널값을 그대로 유지한다.
    final snapshot = parsed.emgChannelPercents.isEmpty
        ? parsed.copyWith(emgChannelPercents: _lastEmgChannelPercents)
        : parsed;
    _lastEmgChannelPercents = snapshot.emgChannelPercents;

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
      // glass_display_data(~50Hz)는 throttle, 그 외 상태 변화는 즉시 반영.
      if (message is UnknownPiMessage &&
          message.type == SmartglassSnapshotMessageType.glassDisplayData) {
        _throttledNotify();
      } else {
        notifyListeners();
      }
    }
  }

  /// leading + trailing throttle: 첫 알림은 즉시, 쿨다운(_liveNotifyInterval)
  /// 동안 들어온 갱신은 마지막 1건만 모아서 반영한다. 최신 _state 는 항상
  /// 동기 갱신되므로 알림이 늦어도 표시 값이 손실되지 않는다.
  void _throttledNotify() {
    if (_liveNotifyTimer != null) {
      _liveNotifyPending = true;
      return;
    }
    notifyListeners();
    _liveNotifyTimer = Timer(_liveNotifyInterval, () {
      _liveNotifyTimer = null;
      if (_liveNotifyPending) {
        _liveNotifyPending = false;
        _throttledNotify();
      }
    });
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
    // 새 운동 시작 시 직전 세션의 EMG 채널값이 남지 않도록 초기화.
    _lastEmgChannelPercents = const [];
    return changed;
  }

  @override
  void dispose() {
    _piSubscription?.cancel();
    _piSubscription = null;
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _mockPlaybackTimer?.cancel();
    _liveNotifyTimer?.cancel();
    super.dispose();
  }
}
