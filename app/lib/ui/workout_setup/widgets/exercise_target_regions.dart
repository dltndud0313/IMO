/// 자세 가이드 화면에서 운동별 타겟 근육을 SVG 바디 위에 색으로 강조하기 위한
/// 매핑.
///
/// 출처: `app/docs/muscle_heatmap_svg_integration_v3.md` 의
/// "MVP 운동별 추천 매핑" 섹션. 이 매핑은 Pi 가 송신하는 `muscle_map_key`
/// 와 SVG `path id` 가 일치하는 표준 키 집합을 사용한다.
///
/// 통계 탭의 muscleMap 데이터 흐름 (`buildBodyHeatmapRegionsFromData`) 과
/// 는 별개로, 정적인 "이 운동의 타겟은 어디" 정보만 표현한다.
library;

import 'package:flutter/widgets.dart';

/// 운동 한 종목의 타겟 근육 분류.
///
/// - [primary]: 주동근 (primary mover). 자세 가이드 SVG 에서 강한 색으로 강조.
/// - [supporting]: 보조근 (synergist). 약한 색으로 강조.
///
/// 좌·우 분리 키 (`left_chest` / `right_chest`) 를 모두 명시한다.
/// SVG path id 가 좌우로 분리되어 있어 한쪽만 강조하면 비대칭으로 보임.
class ExerciseTargetMap {
  const ExerciseTargetMap({
    required this.primary,
    required this.supporting,
  });

  final List<String> primary;
  final List<String> supporting;

  /// SVG ColorMapper 에 넘길 `{muscleKey: 0~100 활성도}` 맵 생성.
  ///
  /// - primary → 95 (강한 빨강 영역)
  /// - supporting → 50 (보통 색상)
  ///
  /// 활성도 단계는 `SvgBodyHeatmapView._colorForPercent` 의 구간에 맞춰 선택:
  /// `< 20: low alpha`, `< 40: low`, `< 60: normal`, `< 80: high`, `else: danger`.
  Map<String, double> toIntensityMap({
    double primaryIntensity = 95.0,
    double supportingIntensity = 50.0,
  }) {
    return {
      for (final key in primary) key: primaryIntensity,
      for (final key in supporting) key: supportingIntensity,
    };
  }

  /// 전면 SVG 에 표시할 키만 반환.
  Iterable<String> get frontKeys =>
      [...primary, ...supporting].where(_isFrontKey);

  /// 후면 SVG 에 표시할 키만 반환.
  Iterable<String> get backKeys =>
      [...primary, ...supporting].where(_isBackKey);

  bool get hasFrontTargets => frontKeys.isNotEmpty;

  bool get hasBackTargets => backKeys.isNotEmpty;
}

/// v3 SVG path id 기준 후면 근육 식별.
///
/// 후면 키워드를 직접 명시한다. SVG 파일에서 후면 자산
/// (`*_back_body.svg`) 에 들어있는 path id 와 일치.
bool _isBackKey(String key) {
  const backKeywords = [
    'triceps',
    'upper_trapezius',
    'latissimus_dorsi',
    'lower_back',
    'rear_deltoid',
    'glute',
    'hamstrings',
    'calves',
  ];
  return backKeywords.any(key.contains);
}

bool _isFrontKey(String key) => !_isBackKey(key);

/// MVP 3종 운동의 타겟 근육 매핑.
///
/// `muscle_heatmap_svg_integration_v3.md` 의 표를 코드로 옮긴 것.
/// 운동 추가 시 여기에 키만 더하면 됨.
const exerciseTargetMap = <String, ExerciseTargetMap>{
  // 푸시업 — 가슴·삼두·전면 삼각근이 주동근, 이두는 보조 안정
  'pushup': ExerciseTargetMap(
    primary: [
      'left_chest',
      'right_chest',
      'left_triceps',
      'right_triceps',
      'left_anterior_deltoid',
      'right_anterior_deltoid',
    ],
    supporting: [
      'left_biceps',
      'right_biceps',
    ],
  ),

  // 사이드 레터럴 레이즈 (싸레레) — 측면 삼각근 주동, 상부 승모근 보조
  'lateral_raise': ExerciseTargetMap(
    primary: [
      'left_lateral_deltoid',
      'right_lateral_deltoid',
    ],
    supporting: [
      'left_upper_trapezius',
      'right_upper_trapezius',
    ],
  ),

  // 이두컬 — 이두근 주동, 전완과 전면 삼각근이 보조
  'bicep_curl': ExerciseTargetMap(
    primary: [
      'left_biceps',
      'right_biceps',
    ],
    supporting: [
      'left_forearm',
      'right_forearm',
      'left_anterior_deltoid',
      'right_anterior_deltoid',
    ],
  ),
};

/// `exerciseId` 로 타겟 매핑 조회. 매핑 없는 운동이면 `null`.
ExerciseTargetMap? findExerciseTargetMap(String exerciseId) {
  return exerciseTargetMap[exerciseId];
}

/// 자세 가이드 SVG 의 줌인 / 시야 설정.
///
/// 원본 SVG viewBox 는 `0 -80 724 1450` (가로 724, 세로 1450, 비율 ≈ 0.5).
/// 머리·발끝까지 전신이 들어있어 그대로 보여주면 타겟 근육이 작게 보임.
///
/// - [alignment]: 보여줄 영역의 정렬. `Alignment(0, -0.5)` 는 위쪽으로 시야 이동
///   (= 상체 중심). `Alignment.center` 는 전신.
/// - [zoom]: 줌 배율. 1.0 은 원본 영역 모두 보임, 1.6 은 1.6배 확대 후 잘라 보여줌.
class BodyCropConfig {
  const BodyCropConfig({required this.alignment, required this.zoom});

  final Alignment alignment;
  final double zoom;
}

/// 상체 중심 기본 crop. 부위 매핑 없는 운동에 적용.
const upperBodyCrop = BodyCropConfig(
  alignment: Alignment(0, -0.55),
  zoom: 1.6,
);

/// 운동별 미세 조정된 crop. hot reload 로 시각 튜닝.
///
/// 푸시업: 상체 wide (가슴 + 어깨 + 팔)
/// 사이드 레터럴: 어깨 + 상부 승모근 (조금 더 타이트하게 위)
/// 이두컬: 팔 중심 (가슴부터 손까지)
const exerciseBodyCrops = <String, BodyCropConfig>{
  'pushup': BodyCropConfig(alignment: Alignment(0, -0.55), zoom: 1.6),
  'lateral_raise': BodyCropConfig(alignment: Alignment(0, -0.65), zoom: 1.8),
  'bicep_curl': BodyCropConfig(alignment: Alignment(0, -0.45), zoom: 1.7),
};

BodyCropConfig findExerciseBodyCrop(String exerciseId) {
  return exerciseBodyCrops[exerciseId] ?? upperBodyCrop;
}
