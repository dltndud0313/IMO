/// 로컬 데이터베이스 서비스 정의 (SQLite)
/// - 오프라인 캐싱, 운동 기록 임시 저장 등을 담당.
class LocalDbService {
  // TODO: drift 또는 sqflite 등 DB 초기화 로직 구현.
  
  Future<void> init() async {
    // DB 파일 열기 및 마이그레이션
  }
  
  // ─── 세션 기록 ───
  
  // Future<void> insertSession(WorkoutSession session) async { ... }
  // Future<List<WorkoutSession>> getSessions(...) async { ... }
  
  // ─── 캘리브레이션 값 캐싱 ───
  
  // Future<void> saveCalibration(CalibrationData data) async { ... }
  // Future<CalibrationData?> loadCalibration() async { ... }
}
