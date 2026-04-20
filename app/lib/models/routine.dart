/// 운동 루틴을 구성하는 개별 항목.
class RoutineItem {
  final int? id;
  final int? routineId;
  final String exerciseId; // 'pushup', 'curl', 'lateral_raise'
  final int sets;
  final int targetReps;
  final int restSeconds;
  final int sortOrder;

  const RoutineItem({
    this.id,
    this.routineId,
    required this.exerciseId,
    required this.sets,
    required this.targetReps,
    this.restSeconds = 60,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        if (routineId != null) 'routine_id': routineId,
        'exercise_id': exerciseId,
        'sets': sets,
        'target_reps': targetReps,
        'rest_seconds': restSeconds,
        'sort_order': sortOrder,
      };

  factory RoutineItem.fromMap(Map<String, dynamic> map) => RoutineItem(
        id: map['id'] as int?,
        routineId: map['routine_id'] as int?,
        exerciseId: map['exercise_id'] as String,
        sets: map['sets'] as int,
        targetReps: map['target_reps'] as int,
        restSeconds: map['rest_seconds'] as int,
        sortOrder: map['sort_order'] as int,
      );

  RoutineItem copyWith({
    int? id,
    int? routineId,
    String? exerciseId,
    int? sets,
    int? targetReps,
    int? restSeconds,
    int? sortOrder,
  }) =>
      RoutineItem(
        id: id ?? this.id,
        routineId: routineId ?? this.routineId,
        exerciseId: exerciseId ?? this.exerciseId,
        sets: sets ?? this.sets,
        targetReps: targetReps ?? this.targetReps,
        restSeconds: restSeconds ?? this.restSeconds,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}

/// 운동 루틴 (여러 RoutineItem을 묶은 단위).
class Routine {
  final int? id;
  final String name;
  final DateTime createdAt;
  final List<RoutineItem> items;

  const Routine({
    this.id,
    required this.name,
    required this.createdAt,
    this.items = const [],
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'created_at': createdAt.toIso8601String(),
      };

  factory Routine.fromMap(Map<String, dynamic> map,
          {List<RoutineItem> items = const []}) =>
      Routine(
        id: map['id'] as int?,
        name: map['name'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
        items: items,
      );

  /// 전체 예상 시간 (운동 + 휴식)
  int get estimatedMinutes {
    var totalSec = 0;
    for (final item in items) {
      // 세트당 약 30초 운동 + 휴식
      totalSec += item.sets * 30 + (item.sets - 1) * item.restSeconds;
    }
    return (totalSec / 60).ceil();
  }

  Routine copyWith({
    int? id,
    String? name,
    DateTime? createdAt,
    List<RoutineItem>? items,
  }) =>
      Routine(
        id: id ?? this.id,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
        items: items ?? this.items,
      );
}
