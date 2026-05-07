import '../../data/services/pi_message.dart';

abstract interface class ICalibrationRepository {
  Stream<CalibrationStatusMessage> get status;
}
