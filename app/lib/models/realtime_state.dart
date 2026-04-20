/// Pi에서 들어올 실시간 상태 (mock)
/// 추후 ws_message.dart의 RealtimeMsg로 대체될 예정.
enum RepSpeed { fast, normal, slow }

class RealtimeState {
  final int repCount;
  final RepSpeed speed;
  final bool isCompensation;
  final bool isFatigued;
  final double ch1;
  final double ch2;
  final double ch3;

  const RealtimeState({
    required this.repCount,
    required this.speed,
    required this.isCompensation,
    required this.isFatigued,
    required this.ch1,
    required this.ch2,
    required this.ch3,
  });

  static const empty = RealtimeState(
    repCount: 0,
    speed: RepSpeed.normal,
    isCompensation: false,
    isFatigued: false,
    ch1: 0,
    ch2: 0,
    ch3: 0,
  );
}

/// 세션 종료 시 결과
class SessionResult {
  final int totalReps;
  final int compensationCount;
  final double avgCh1;
  final double avgCh2;
  final double avgCh3;
  final String comment;

  const SessionResult({
    required this.totalReps,
    required this.compensationCount,
    required this.avgCh1,
    required this.avgCh2,
    required this.avgCh3,
    required this.comment,
  });
}

// SessionRecord는 lib/models/session_record.dart 로 분리됨.
