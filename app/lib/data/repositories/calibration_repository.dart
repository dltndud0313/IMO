import 'dart:async';

import '../../domain/models/calibration_data.dart';
import '../services/local_db_service.dart';
import '../services/pi_socket_service.dart';

/// 캘리브레이션 트리거 및 결과 수신
class CalibrationRepository {
  final PiSocketService _socket;
  final LocalDbService _localDb; // 캐싱용

  CalibrationData? _lastResult;

  CalibrationRepository(this._socket, this._localDb);

  CalibrationData? get lastResult => _lastResult;

  /// 캘리브레이션 시작 요청 (동시에 글래스 모드 전환 트리거됨)
  Future<bool> startCalibration() async {
    _socket.sendCalibrationStart();
    try {
      final ack = await _socket.calibrationStartAck.first.timeout(const Duration(seconds: 5));
      return ack.calibrationStarted && ack.glassModeActivated;
    } catch (_) {
      return false;
    }
  }

  /// 캘리브레이션 진행 스트림
  Stream<CalibrationProgress> get progress =>
      _socket.calibrationProgress.map((m) => m.progress);

  /// 캘리브레이션 결과 수신 대기 (진행 시작 후 대기)
  Future<CalibrationData> waitForResult() async {
    final resultMsg = await _socket.calibrationResult.first;
    _lastResult = resultMsg.calibration;
    // _localDb.saveCalibration(_lastResult!) // 결과 로컬 저장 (선택)
    return _lastResult!;
  }
}
