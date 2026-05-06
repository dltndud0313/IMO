import '../services/pi_message.dart';
import '../services/pi_socket_service.dart';

class CalibrationRepository {
  CalibrationRepository(this._socket);

  final PiSocketService _socket;

  Stream<CalibrationStatusMessage> get status =>
      _socket.messagesOf<CalibrationStatusMessage>();

  Future<void> connect() {
    return _socket.connect();
  }

  void startCalibration({
    required String exerciseType,
  }) {
    _socket.startCalibration(exerciseType: exerciseType);
  }

  void markSensorsAttached() {
    _socket.markSensorsAttached();
  }
}
