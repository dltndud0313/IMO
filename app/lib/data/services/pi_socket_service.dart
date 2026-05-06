import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'pi_message.dart';

enum PiSocketConnectionState {
  disconnected,
  connecting,
  connected,
}

class PiSocketService {
  PiSocketService({
    String url = 'ws://192.168.0.100:8765',
  }) : _url = url;

  final String _url;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

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
      final channel = WebSocketChannel.connect(Uri.parse(_url));
      _channel = channel;
      _subscription = channel.stream.listen(
        _handleRawMessage,
        onError: _handleSocketError,
        onDone: _handleSocketDone,
        cancelOnError: true,
      );
      _setConnectionState(PiSocketConnectionState.connected);
    } catch (error, stackTrace) {
      log(
        '[PiSocketService] connect failed',
        error: error,
        stackTrace: stackTrace,
      );
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

    _channel!.sink.add(jsonEncode(message.toJson()));
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
      log('[PiSocketService] ignored non-string message: $rawData');
      return;
    }

    try {
      final decoded = jsonDecode(rawData);
      if (decoded is! Map<String, dynamic>) {
        log('[PiSocketService] ignored non-object JSON: $rawData');
        return;
      }

      final message = PiMessage.tryParse(decoded);
      if (message == null) {
        log('[PiSocketService] ignored invalid Pi message: $rawData');
        return;
      }

      _messageController.add(message);
    } catch (error, stackTrace) {
      log(
        '[PiSocketService] message parse failed: $rawData',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _handleSocketError(Object error, StackTrace stackTrace) {
    log(
      '[PiSocketService] socket error',
      error: error,
      stackTrace: stackTrace,
    );
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
