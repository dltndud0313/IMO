import 'dart:async';

import '../../domain/models/connection_status.dart';
import '../services/pi_socket_service.dart';

/// 디바이스 연결 상태 Stream
class DeviceConnectionRepository {
  final PiSocketService _socket;

  DeviceConnectionRepository(this._socket);

  /// 소켓 연결 상태 자체
  Stream<SocketConnectionState> get connectionState => _socket.connectionState;

  /// 시스템/센서 연결 상태 (Pi에서 쏴주는 상태 메시지)
  Stream<ConnectionStatus> get systemStatus =>
      _socket.systemStatus.map((m) => m.status);

  /// 1회성 요청
  void requestSystemStatus() {
    _socket.sendSystemStatusRequest();
  }

  /// 특정 컴포넌트(EMG 등) 재연결 요청
  void requestReconnect(String targetComponent, {int? channelId}) {
    _socket.sendReconnectRequest(targetComponent: targetComponent, channelId: channelId);
  }
}
