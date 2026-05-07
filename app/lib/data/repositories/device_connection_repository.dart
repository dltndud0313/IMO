import '../services/pi_message.dart';
import '../services/pi_socket_service.dart';
import '../../domain/repositories/device_connection_repository_interface.dart';

class DeviceConnectionRepository implements IDeviceConnectionRepository {
  DeviceConnectionRepository(this._socket);

  final PiSocketService _socket;

  Stream<PiSocketConnectionState> get connectionState =>
      _socket.connectionState;

  @override
  Stream<ConnectionStatusMessage> get systemStatus =>
      _socket.messagesOf<ConnectionStatusMessage>();

  Future<void> connect() {
    return _socket.connect();
  }

  Future<void> disconnect() {
    return _socket.disconnect();
  }
}
