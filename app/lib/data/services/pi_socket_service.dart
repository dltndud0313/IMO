import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'pi_message.dart';

enum PiSocketConnectionState {
  disconnected,
  connecting,
  connected,
}

class PiSocketService {
  PiSocketService({
    // String url = 'ws://192.168.100.253:8765',
    // String url = 'ws://172.20.10.10:8765',
    // String url = 'ws://172.20.10.4:8765', 수영 폰
    // String url = 'ws://0.0.0.0:8765',
    String url = 'ws://192.168.0.45:8765',

    bool verboseLogging = false,
  }) 
  
  
   : _url = url,
        _verboseLogging = verboseLogging;

  final String _url;
  final bool _verboseLogging;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  DateTime? _lastSensorFrameLogAt;
  DateTime? _lastGlassDisplayLogAt;

  final _messageController = StreamController<PiMessage>.broadcast();
  final _connectionController =
      StreamController<PiSocketConnectionState>.broadcast();

  PiSocketConnectionState _connectionState =
      PiSocketConnectionState.disconnected;

  Stream<PiMessage> get messages => _messageController.stream;
  Stream<PiSocketConnectionState> get connectionState =>
      _connectionController.stream;

  bool get isConnected => _connectionState == PiSocketConnectionState.connected;

  Stream<T> messagesOf<T extends PiMessage>() {
    return messages.where((message) => message is T).cast<T>();
  }

  Future<void> connect() async {
    if (_connectionState == PiSocketConnectionState.connecting ||
        _connectionState == PiSocketConnectionState.connected) {
      return;
    }

    _setConnectionState(PiSocketConnectionState.connecting);

    try {
      debugPrint('[PiSocketService] connecting to $_url');
      final channel = WebSocketChannel.connect(Uri.parse(_url));
      _channel = channel;
      _subscription = channel.stream.listen(
        _handleRawMessage,
        onError: _handleSocketError,
        onDone: _handleSocketDone,
        cancelOnError: true,
      );
      _setConnectionState(PiSocketConnectionState.connected);
      debugPrint('[PiSocketService] connected to $_url');
    } catch (_) {
      await disconnect();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    _setConnectionState(PiSocketConnectionState.disconnected);
  }

  void send(OutgoingPiMessage message) {
    if (!isConnected || _channel == null) {
      throw StateError('Pi socket is not connected.');
    }

    final encoded = jsonEncode(message.toJson());
    debugPrint('[PiSocketService] send $encoded');
    _channel!.sink.add(encoded);
  }

  void submitWorkoutPlan({
    required String exerciseType,
    required int setCount,
    required List<int> targetRepsPerSet,
    required int restSec,
  }) {
    send(
      OutgoingPiMessage(
        type: PiMessageType.submitWorkoutPlan,
        payload: {
          'exercise_type': exerciseType,
          'set_count': setCount,
          'target_reps_per_set': targetRepsPerSet,
          'rest_sec': restSec,
        },
      ),
    );
  }

  void startCalibration({
    required String exerciseType,
  }) {
    send(
      OutgoingPiMessage(
        type: PiMessageType.startCalibration,
        payload: {
          'exercise_type': exerciseType,
        },
      ),
    );
  }

  void startWorkout() {
    send(
      const OutgoingPiMessage(
        type: PiMessageType.startWorkout,
        payload: {},
      ),
    );
  }

  void markSensorsAttached() {
    send(
      const OutgoingPiMessage(
        type: PiMessageType.sensorsAttached,
        payload: {},
      ),
    );
  }

  void pauseWorkout({
    String reason = 'user_request',
  }) {
    send(
      OutgoingPiMessage(
        type: PiMessageType.pauseWorkout,
        payload: {
          'reason': reason,
        },
      ),
    );
  }

  void resumeWorkout({
    String reason = 'user_request',
  }) {
    send(
      OutgoingPiMessage(
        type: PiMessageType.resumeWorkout,
        payload: {
          'reason': reason,
        },
      ),
    );
  }

  void stopWorkout({
    String reason = 'user_request',
    bool saveResult = true,
  }) {
    send(
      OutgoingPiMessage(
        type: PiMessageType.stopWorkout,
        payload: {
          'reason': reason,
          'save_result': saveResult,
        },
      ),
    );
  }

  void emergencyStop({
    String reason = 'user_emergency',
  }) {
    send(
      OutgoingPiMessage(
        type: PiMessageType.emergencyStop,
        payload: {
          'reason': reason,
        },
      ),
    );
  }

  Future<void> dispose() async {
    await disconnect();
    await _messageController.close();
    await _connectionController.close();
  }

  void _handleRawMessage(dynamic rawData) {
    if (rawData is! String) {
      return;
    }

    try {
      final decoded = jsonDecode(rawData);
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      _logIncomingMessage(decoded, rawData);

      final message = PiMessage.tryParse(decoded);
      if (message == null) {
        debugPrint(
          '[PiSocketService] ignored invalid Pi message: '
          '${_messageSummary(decoded)}',
        );
        return;
      }

      _messageController.add(message);
    } catch (_) {
      debugPrint('[PiSocketService] message parse failed: $rawData');
    }
  }

  void _logIncomingMessage(Map<String, dynamic> decoded, String rawData) {
    if (_verboseLogging) {
      debugPrint('[PiSocketService] receive $rawData');
      return;
    }

    final type = decoded['type'];
    final now = DateTime.now();
    if (type == 'sensor_frame') {
      if (!_shouldLogThrottled(now, _lastSensorFrameLogAt)) {
        return;
      }
      _lastSensorFrameLogAt = now;
    } else if (type == 'glass_display_data') {
      if (!_shouldLogThrottled(
        now,
        _lastGlassDisplayLogAt,
        interval: const Duration(seconds: 1),
      )) {
        return;
      }
      _lastGlassDisplayLogAt = now;
    }

    debugPrint('[PiSocketService] receive ${_messageSummary(decoded)}');
  }

  bool _shouldLogThrottled(
    DateTime now,
    DateTime? lastLogAt, {
    Duration interval = const Duration(seconds: 2),
  }) {
    return lastLogAt == null || now.difference(lastLogAt) >= interval;
  }

  String _messageSummary(Map<String, dynamic> decoded) {
    final payload = decoded['payload'];
    final payloadMap = payload is Map<String, dynamic> ? payload : const {};
    final type = decoded['type'] ?? 'unknown';
    final details = <String>[];

    void add(String label, Object? value) {
      if (value != null) {
        details.add('$label=$value');
      }
    }

    add('seq', payloadMap['seq'] ?? payloadMap['frame_seq']);
    add('phase', payloadMap['phase']);
    add('rep', payloadMap['current_rep'] ?? payloadMap['rep_index']);
    add('activation', payloadMap['activation_percent']);
    add('status', payloadMap['status']);
    add('requestId', decoded['requestId']);

    // ch4=0 디버깅용. glass_display_data: 채널별 정규화 결과, sensor_frame: ESP raw.
    if (type == 'glass_display_data') {
      final channelsSummary = _emgChannelsSummary(payloadMap['emg_channels']);
      if (channelsSummary != null) {
        details.add('emg=$channelsSummary');
      }
    } else if (type == 'sensor_frame') {
      final rawSummary = _emgRawSummary(payloadMap['emg']);
      if (rawSummary != null) {
        details.add('emg_raw=$rawSummary');
      }
      // Pi rep counter 가 IMU accel/gyro magnitude 를 같이 보기 때문에
      // rep 미카운트 디버깅 시 IMU 값과 motion 플래그가 필수.
      final imuSummary = _imuSummary(payloadMap['imus']);
      if (imuSummary != null) {
        details.add('imu=$imuSummary');
      }
      final flagDetail = payloadMap['flag_detail'];
      if (flagDetail is Map) {
        final motion = flagDetail['motion_detected'];
        if (motion is bool) {
          details.add('motion=${motion ? "Y" : "N"}');
        }
      }
    }

    return details.isEmpty ? 'type=$type' : 'type=$type ${details.join(' ')}';
  }

  /// `[ch1 attached%, ch2 ..., ch3 ..., ch4 ...]` 형태로 4채널 표시.
  /// attached=false 인 채널은 `-` 로 표시해 0% 와 구분한다.
  String? _emgChannelsSummary(Object? rawChannels) {
    if (rawChannels is! List || rawChannels.isEmpty) {
      return null;
    }
    final parts = <String>[];
    for (var index = 0; index < 4; index += 1) {
      if (index >= rawChannels.length) {
        parts.add('-');
        continue;
      }
      final entry = rawChannels[index];
      if (entry is! Map) {
        parts.add('-');
        continue;
      }
      if (entry['attached'] == false) {
        parts.add('-');
        continue;
      }
      final percent = entry['activation_percent'];
      parts.add(percent is num ? '${percent.round()}%' : '?');
    }
    return '[${parts.join(',')}]';
  }

  String? _emgRawSummary(Object? rawEmg) {
    if (rawEmg is! List || rawEmg.isEmpty) {
      return null;
    }
    final parts = <String>[];
    for (var index = 0; index < 4; index += 1) {
      if (index >= rawEmg.length) {
        parts.add('-');
        continue;
      }
      final value = rawEmg[index];
      parts.add(value is num ? value.toStringAsFixed(3) : '?');
    }
    return '[${parts.join(',')}]';
  }

  /// `imus: [{index, accel:[x,y,z], gyro:[x,y,z]}, ...]` → `[1:a0.98/g1.30 2:a0.05/g0.20]`
  /// accel/gyro 는 3축 벡터 크기(magnitude). 단위는 Pi 가 보내는 그대로(가속도 g, 자이로 rad/s 또는 deg/s).
  String? _imuSummary(Object? rawImus) {
    if (rawImus is! List || rawImus.isEmpty) {
      return null;
    }
    final parts = <String>[];
    for (final entry in rawImus) {
      if (entry is! Map) continue;
      final indexValue = entry['index'];
      final indexLabel =
          indexValue is num ? indexValue.round().toString() : '?';
      final accelMag = _vec3Magnitude(entry['accel']);
      final gyroMag = _vec3Magnitude(entry['gyro']);
      parts.add(
        '$indexLabel:a${accelMag.toStringAsFixed(2)}/g${gyroMag.toStringAsFixed(2)}',
      );
    }
    return parts.isEmpty ? null : '[${parts.join(' ')}]';
  }

  double _vec3Magnitude(Object? raw) {
    if (raw is! List) return 0;
    double sumSq = 0;
    for (var i = 0; i < raw.length && i < 3; i += 1) {
      final v = raw[i];
      if (v is num) {
        final d = v.toDouble();
        sumSq += d * d;
      }
    }
    return math.sqrt(sumSq);
  }

  void _handleSocketError(Object error, StackTrace stackTrace) {
    unawaited(disconnect());
  }

  void _handleSocketDone() {
    unawaited(disconnect());
  }

  void _setConnectionState(PiSocketConnectionState state) {
    if (_connectionState == state) {
      return;
    }

    _connectionState = state;
    if (!_connectionController.isClosed) {
      _connectionController.add(state);
    }
  }
}
