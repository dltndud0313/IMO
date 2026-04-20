/// 운동 세션 기록 모델 (DB 테이블 'sessions' 매핑).
class SessionRecord {
  final int? id;
  final DateTime date;
  final String exerciseName;
  final int totalReps;
  final int compensationCount;
  final double avgCh1;
  final double avgCh2;
  final double avgCh3;
  final String comment;

  const SessionRecord({
    this.id,
    required this.date,
    required this.exerciseName,
    required this.totalReps,
    required this.compensationCount,
    required this.avgCh1,
    required this.avgCh2,
    required this.avgCh3,
    required this.comment,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'date': date.toIso8601String(),
        'exercise_name': exerciseName,
        'total_reps': totalReps,
        'compensation_count': compensationCount,
        'avg_ch1': avgCh1,
        'avg_ch2': avgCh2,
        'avg_ch3': avgCh3,
        'comment': comment,
      };

  factory SessionRecord.fromMap(Map<String, dynamic> map) => SessionRecord(
        id: map['id'] as int?,
        date: DateTime.parse(map['date'] as String),
        exerciseName: map['exercise_name'] as String,
        totalReps: map['total_reps'] as int,
        compensationCount: map['compensation_count'] as int,
        avgCh1: (map['avg_ch1'] as num).toDouble(),
        avgCh2: (map['avg_ch2'] as num).toDouble(),
        avgCh3: (map['avg_ch3'] as num).toDouble(),
        comment: map['comment'] as String,
      );

  /// 보상동작 비율 (0~1)
  double get compensationRatio =>
      totalReps > 0 ? compensationCount / totalReps : 0;

  /// 날짜 포맷: "2026.04.13"
  String get formattedDate =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

  /// 날짜+시간 포맷: "2026.04.13  14:30"
  String get formattedDateTime =>
      '$formattedDate  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
