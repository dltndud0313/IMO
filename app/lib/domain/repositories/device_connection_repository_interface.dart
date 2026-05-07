import '../../data/services/pi_message.dart';

abstract interface class IDeviceConnectionRepository {
  Stream<ConnectionStatusMessage> get systemStatus;
}
