import '../services/pi_message.dart';
import '../services/pi_socket_service.dart';

class DeviceConnectionRepository {
  DeviceConnectionRepository(this._socket);

  final PiSocketService _socket;

  Stream<PiSocketConnectionState> get connectionState =>
      _socket.connectionState;

  Stream<ConnectionStatusMessage> get systemStatus =>
      _socket.messagesOf<ConnectionStatusMessage>();

  Future<void> connect() {
    return _socket.connect();
  }

  Future<void> disconnect() {
    return _socket.disconnect();
  }
}
