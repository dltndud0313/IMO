import 'dart:async';

import '../../data/repositories/calibration_repository.dart';
import '../../data/repositories/device_connection_repository.dart';
import '../models/connection_status.dart';

/// 시스템 (센서 및 디바이스) 준비 완료 여부 판정
class CheckSystemReadyUseCase {
  final DeviceConnectionRepository _deviceRepo;
  final CalibrationRepository _calibrationRepo;

  CheckSystemReadyUseCase(this._deviceRepo, this._calibrationRepo);

  /// 운동 시작 전 체크리스트 확인
  /// 1. 모든 센서(EMG, IMU) 연결 여부
  /// 2. 캘리브레이션 유효성
  Future<bool> execute() async {
    // 1. 최신 시스템 상태 검사
    _deviceRepo.requestSystemStatus();
    final status = await _deviceRepo.systemStatus.first.timeout(const Duration(seconds: 3));
    
    if (!status.readyToStart) {
      return false; // 센서 등 물리적 연결이나 상태 이상
    }

    // 2. 캘리브레이션 완료 여부 검사
    final calData = _calibrationRepo.lastResult;
    if (calData == null || !calData.readyToStart) {
      return false;
    }

    return true;
  }
}
