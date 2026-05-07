import 'dart:async';

import '../../domain/repositories/calibration_repository_interface.dart';
import '../../domain/repositories/device_connection_repository_interface.dart';
import '../../data/services/pi_message.dart';

class CheckSystemReadyUseCase {
  CheckSystemReadyUseCase(this._deviceRepo, this._calibrationRepo);

  final IDeviceConnectionRepository _deviceRepo;
  final ICalibrationRepository _calibrationRepo;

  Future<bool> execute() async {
    final connection = await _deviceRepo.systemStatus.first.timeout(
      const Duration(seconds: 3),
      onTimeout: () => const ConnectionStatusMessage(
        piConnected: false,
        esp32Connected: false,
        glassConnected: false,
      ),
    );

    if (!connection.piConnected ||
        !connection.esp32Connected ||
        !connection.glassConnected) {
      return false;
    }

    final calibration = await _calibrationRepo.status.first.timeout(
      const Duration(seconds: 3),
      onTimeout: () => const CalibrationStatusMessage(
        status: 'failed',
        message: 'Calibration status timeout',
      ),
    );

    return calibration.isSuccess;
  }
}
