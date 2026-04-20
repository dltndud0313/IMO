import 'dart:convert';
import 'dart:ui';

/// 포즈 랜드마크 데이터.
/// Google ML Kit는 33개 포인트를 반환하지만 모두 정규화(0~1) 좌표로 저장.
/// key = PoseLandmarkType의 이름 (예: 'leftShoulder')
/// value = Offset(x, y) — 0~1 정규화된 위치
class PoseData {
  final Map<String, Offset> landmarks;

  const PoseData({required this.landmarks});

  Offset? get(String key) => landmarks[key];

  Map<String, dynamic> toJson() => {
        'landmarks': landmarks.map(
          (k, v) => MapEntry(k, [v.dx, v.dy]),
        ),
      };

  factory PoseData.fromJson(Map<String, dynamic> json) {
    final raw = json['landmarks'] as Map<String, dynamic>;
    return PoseData(
      landmarks: raw.map((k, v) {
        final list = (v as List).cast<num>();
        return MapEntry(k, Offset(list[0].toDouble(), list[1].toDouble()));
      }),
    );
  }

  String encode() => jsonEncode(toJson());
  static PoseData decode(String s) =>
      PoseData.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
