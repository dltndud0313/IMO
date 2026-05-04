/// 운동 종목 enum
/// API 명세: ExerciseType enum, GET /exercises (API-16)
enum ExerciseType {
  pushUp('PUSH_UP', '푸시업'),
  lateralRaise('LATERAL_RAISE', '사이드 레터럴 레이즈'),
  bicepCurl('BICEP_CURL', '이두컬');

  final String wire; // JSON 전송용 문자열
  final String label; // UI 표시용 한글명
  const ExerciseType(this.wire, this.label);

  static ExerciseType fromWire(String s) {
    final normalized = s.trim().toUpperCase().replaceAll('-', '_');
    final compact = normalized.replaceAll('_', '');

    return switch (compact) {
      'PUSHUP' => pushUp,
      'LATERALRAISE' => lateralRaise,
      'BICEPCURL' => bicepCurl,
      _ => throw FormatException('unknown exerciseType: $s'),
    };
  }
}

/// 센서 부착 위치 (API-16, WS-04)
class SensorPlacement {
  final List<EmgPlacement> emg;
  final ImuPlacement imu;
  const SensorPlacement({required this.emg, required this.imu});

  factory SensorPlacement.fromJson(Map<String, dynamic> json) {
    return SensorPlacement(
      emg: (json['emg'] as List)
          .map((e) => EmgPlacement.fromJson(e as Map<String, dynamic>))
          .toList(),
      imu: ImuPlacement.fromJson(json['imu'] as Map<String, dynamic>),
    );
  }
}

class EmgPlacement {
  final int channelId;
  final String muscleName;
  final String side; // CENTER / LEFT / RIGHT
  final String description;

  const EmgPlacement({
    required this.channelId,
    required this.muscleName,
    required this.side,
    required this.description,
  });

  factory EmgPlacement.fromJson(Map<String, dynamic> json) => EmgPlacement(
        channelId: json['channelId'] as int,
        muscleName: json['muscleName'] as String,
        side: json['side'] as String,
        description: json['description'] as String,
      );
}

class ImuPlacement {
  final String bodyPart;
  final String description;
  const ImuPlacement({required this.bodyPart, required this.description});

  factory ImuPlacement.fromJson(Map<String, dynamic> json) => ImuPlacement(
        bodyPart: json['bodyPart'] as String,
        description: json['description'] as String,
      );
}

/// 운동 종목 정보 (API-16 응답)
class ExerciseInfo {
  final ExerciseType exerciseType;
  final String name;
  final String description;
  final List<String> targetMuscles;
  final List<String> instructions;
  final List<String> cautions;
  final SensorPlacement sensorPlacement;
  final String? thumbnailUrl;

  const ExerciseInfo({
    required this.exerciseType,
    required this.name,
    required this.description,
    required this.targetMuscles,
    required this.instructions,
    required this.cautions,
    required this.sensorPlacement,
    this.thumbnailUrl,
  });

  factory ExerciseInfo.fromJson(Map<String, dynamic> json) => ExerciseInfo(
        exerciseType: ExerciseType.fromWire(json['exerciseType'] as String),
        name: json['name'] as String,
        description: json['description'] as String,
        targetMuscles: (json['targetMuscles'] as List).cast<String>(),
        instructions: (json['instructions'] as List).cast<String>(),
        cautions: (json['cautions'] as List).cast<String>(),
        sensorPlacement: SensorPlacement.fromJson(
            json['sensorPlacement'] as Map<String, dynamic>),
        thumbnailUrl: json['thumbnailUrl'] as String?,
      );
}
