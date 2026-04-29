import '../services/pi_message.dart';
import '../services/pi_socket_service.dart';

class CalibrationRepository {
  CalibrationRepository(this._socket);

  final PiSocketService _socket;

  Stream<CalibrationStatusMessage> get status =>
      _socket.messagesOf<CalibrationStatusMessage>();

  void startCalibration({
    required String exerciseType,
  }) {
    _socket.startCalibration(exerciseType: exerciseType);
  }
}
