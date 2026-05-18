# [APP][Avatar] 2D 아바타 구조 분석 및 3D 전환 범위

## 0. 작업 기준

- 기준 프로젝트 루트: `C:\Users\SSAFY\Desktop\C203\S14P31C203`
- 기준 감사 문서: `docs/avatar_project_audit_report.md`
- 기준 앱 구조: `app/lib/domain`, `app/lib/data`, `app/lib/ui`
- 이번 문서는 분석 및 범위 정의만 다룬다.
- 앱 코드 구현, `pubspec.yaml` 수정, 3D 패키지 설치, 파일 이관은 하지 않는다.
- 이전에 잘못된 경로에 생성된 `C:\Users\SSAFY\Desktop\C203\app` 기준 파일은 이 문서의 판단 기준으로 사용하지 않는다.

## 1. 실제 프로젝트의 현재 히트맵/근육 데이터 구조

### 1.1 `ExerciseType`

파일: `app/lib/domain/models/exercise_type.dart`

실제 프로젝트의 운동 enum은 다음 3개다.

| enum | wire | 의미 |
| --- | --- | --- |
| `ExerciseType.pushUp` | `PUSH_UP` | 푸시업 |
| `ExerciseType.bicepCurl` | `BICEP_CURL` | 이두 컬 |
| `ExerciseType.lateralRaise` | `LATERAL_RAISE` | 사이드 레터럴 레이즈 |

`fromWire`는 대소문자, 하이픈, 언더스코어 차이를 정규화해서 `pushup`, `bicepcurl`, `lateralraise` 형태도 받아들인다.

### 1.2 `ExerciseSensorMapping`

파일: `app/lib/domain/models/exercise_sensor_mapping.dart`

`ExerciseSensorMapping`은 운동별 센서 부착 위치와 `muscle_map` 대표 key를 연결한다.

핵심 필드:

| 필드 | 역할 |
| --- | --- |
| `exerciseId` | 앱 내부 운동 ID. 예: `pushup`, `bicep_curl`, `lateral_raise` |
| `exerciseType` | `ExerciseType` enum |
| `displayName` | UI 표시명 |
| `placements` | EMG/IMU 센서 부착 위치 목록 |
| `muscleMapKeys` | 해당 운동의 대표 `muscle_map` key 목록 |

현재 운동별 대표 key는 다음과 같다.

| 운동 | `muscleMapKeys` |
| --- | --- |
| `pushup` | `left_chest`, `right_chest`, `left_triceps`, `right_triceps`, `trunk` |
| `bicep_curl` | `left_biceps`, `right_biceps`, `left_forearm`, `right_forearm`, `trunk` |
| `lateral_raise` | `left_lateral_deltoid`, `right_lateral_deltoid`, `left_upper_trapezius`, `right_upper_trapezius`, `trunk` |

주의할 점:

- 실제 프로젝트는 예전 `CH1~CH3 + ChannelMapping` 구조가 아니다.
- 현재 매핑은 EMG1~EMG4와 IMU1~IMU3 기준이다.
- `placements`에는 `left_forearm_motion`, `right_forearm_motion` 같은 움직임 분석용 IMU key도 포함된다.
- 하지만 `muscleMapKeys`에는 근육/자세 요약에 쓸 대표 key만 들어간다.

### 1.3 `ExerciseMuscleMapSchema`

파일: `app/lib/domain/models/muscle_map_schema.dart`

`ExerciseMuscleMapSchema`는 운동별 `muscle_map` key의 의미와 값 종류를 정의한다.

핵심 타입:

| 타입 | 역할 |
| --- | --- |
| `MuscleMapValueKind.activation` | 근육 활성도 |
| `MuscleMapValueKind.postureStability` | 자세 안정성 |
| `MuscleMapStatus` | `inactive`, `low`, `normal`, `high`, `danger` |
| `MuscleMapKeyDefinition` | key, 표시명, 값 종류, 설명 |
| `ExerciseMuscleMapSchema` | 운동별 key 정의 모음 |

`trunk`는 모든 운동에서 `postureStability`로 정의되어 있다. 따라서 `trunk`는 근육 히트맵 색상과 같은 의미로 칠하기보다 자세 안정성 또는 보상 움직임 지표로 분리해야 한다.

현재 분류 기준:

| 종류 | 값 | 상태 |
| --- | --- | --- |
| 공통 | `0` | `inactive` |
| 활성도 | `0 < value < 40` | `low` |
| 활성도 | `40 <= value < 70` | `normal` |
| 활성도 | `70 <= value < 90` | `high` |
| 활성도 | `90 <= value <= 100` | `danger` |
| 자세 안정성 | `0 < value < 30` | `danger` |
| 자세 안정성 | `30 <= value < 50` | `low` |
| 자세 안정성 | `50 <= value < 75` | `normal` |
| 자세 안정성 | `75 <= value <= 100` | `high` |

스케일 계약(2026-05-18 통일): 활성도 값은 전 구간 `0~100` percent 다.
`clampMuscleMapPercent`는 표시 직전 `0~100` 범위로 clamp 만 한다(스케일 변환 없음).

### 1.4 `MuscleMapState`

파일: `app/lib/domain/models/muscle_map.dart`

`MuscleMapState`는 세션 또는 raw map을 화면에서 쓰기 쉬운 entry 목록으로 바꾼다.

핵심 흐름:

1. `MuscleMapState.fromWorkoutSession(session)`이 `session.exerciseType.wire`와 `session.muscleMap?.values`를 사용한다.
2. `MuscleMapState.fromValues(...)`가 `ExerciseSensorMapping` 또는 `ExerciseMuscleMapSchema`에서 allowed key를 찾는다.
3. allowed key 순서대로 `MuscleMapEntry`를 만든다.
4. schema에 없는 unknown key가 들어오면 `isKnownKey = false`로 뒤에 추가한다.

중요한 현재 동작:

- `includeMissingKeys` 기본값은 `true`다.
- allowed key가 `values`에 없으면 `values[key] ?? 0`으로 처리된다.
- 따라서 현재 구현에서는 missing key와 실제 0 활성도가 모두 `0`으로 합쳐진다.
- MVP에서 "No data"와 "0 활성도"를 구분하려면 이 정책을 그대로 쓸지, painter 입력 단계에서 별도 null 모델을 둘지 결정해야 한다.

### 1.5 `WorkoutSession.muscleMap`

파일: `app/lib/domain/models/workout_session.dart`

`WorkoutSession`은 운동 결과 도메인 모델이며 `MuscleMap? muscleMap`을 가진다.

```dart
class MuscleMap {
  final Map<String, double> values;
}
```

현재 `WorkoutSession.fromJson`은 `muscle_map`이 있을 때 `MuscleMap.fromJson`으로 변환한다. `toJson`도 `muscleMap != null`이면 `muscle_map`을 보낸다.

주의할 점:

- `MuscleMap` 안의 convenience getter 일부는 `chest`, `left_shoulder`, `right_shoulder`처럼 현재 스키마와 완전히 맞지 않는 오래된 흔적이 있다.
- 신규 아바타 구현은 getter보다 `values`와 `ExerciseMuscleMapSchema`를 기준으로 삼는 편이 안전하다.

### 1.6 `SessionResultDto.muscleMap`

파일: `app/lib/data/dto/session_result_dto.dart`

`SessionResultDto`는 API/세션 결과 payload의 `muscle_map`을 `Map<String, double>`로 받는다.

핵심 흐름:

1. `fromJson`에서 `json['muscle_map']`을 `_asDoubleMap`으로 변환한다.
2. `toJson`에서는 `muscleMap.isNotEmpty`일 때만 `muscle_map`을 포함한다.
3. `toDomain`에서는 `_toDomainMuscleMap(muscleMap)`을 통해 `WorkoutSession.muscleMap`으로 넘긴다.
4. 빈 map이면 domain의 `muscleMap`은 `null`이 된다.

따라서 세션 단위 상세/결과 화면은 `WorkoutSession.muscleMap`을 기준으로 아바타 입력을 만들 수 있다.

### 1.7 `StatsRepository`와 `StatsViewModel`

파일:

- `app/lib/data/repositories/stats_repository.dart`
- `app/lib/data/services/api_service.dart`
- `app/lib/ui/stats/view_model/stats_viewmodel.dart`

통계 탭의 주간 히트맵 데이터 흐름:

1. `StatsViewModel.loadStats(weekStart)`가 `Future.wait`으로 주간 통계, 주간 히트맵, 주간 밸런스를 함께 조회한다.
2. `StatsRepository.getWeeklyHeatmap`이 `ApiService.getWeeklyHeatmap`을 호출한다.
3. `ApiService.getWeeklyHeatmap`은 `GET /statistics/weekly/heatmap`의 `data`를 `Map<String, dynamic>`으로 반환한다.
4. `StatsScreen`은 `HeatmapTab(data: _viewModel.heatmap)`으로 넘긴다.

현재 통계 히트맵은 typed DTO가 아니라 `Map<String, dynamic>`을 직접 UI에 전달한다.

### 1.8 `HeatmapTab`

파일: `app/lib/ui/stats/tabs/heatmap_tab.dart`

현재 `HeatmapTab`은 주간 히트맵 API 응답의 `data['muscles']`를 직접 읽는다.

현재 기대하는 muscle item 형태:

| 필드 | 현재 사용 위치 |
| --- | --- |
| `muscleName` | 라벨 이름 |
| `muscleId` | `muscleName`이 없을 때 fallback 이름 |
| `avgActivation` | percent 라벨 |
| `sessionCount` | 라벨의 세션 수 |

현재 UI는 `muscles.take(7)`까지만 라벨로 표시한다.

## 2. 현재 `HeatmapTab` 구조 분석

### 2.1 전면/후면 segmented control

`HeatmapTab`에는 `_frontSelected` bool 상태가 있고, `_MiniSegmentedControl`로 전면/후면 전환 UI가 있다.

현재 구조:

- 전면 선택: `_frontSelected = true`
- 후면 선택: `_frontSelected = false`
- 전환 시 `setState`로 rebuild
- 이 상태는 현재 아이콘 색상 변경에만 쓰인다.

따라서 2D 구현 시 이 상태를 그대로 사용해 `FrontBodyHeatmapPainter`와 `BackBodyHeatmapPainter`를 전환할 수 있다.

### 2.2 현재 placeholder

현재 placeholder는 실제 인체 실루엣이 아니다.

현재 표시:

- `Icons.accessibility_new_rounded`
- 전면 선택 시 옅은 빨간색 계열
- 후면 선택 시 옅은 파란색 계열
- 별도 `CustomPainter` 없음
- 실제 근육 shape/path 없음

즉, 현재는 "히트맵 UI의 자리"만 있고 실제 2D 인체 실루엣 painter는 없는 상태다.

### 2.3 현재 muscle data 표시 방식

현재는 `Stack` 안에서 아이콘 위/옆에 `_MuscleLabel`을 절대 위치로 올린다.

라벨 포맷:

```text
{muscleName 또는 muscleId}
{avgActivation.round()}%
{sessionCount}
```

라벨 위치는 `_labelPositions` 상수 배열로 고정되어 있다.

한계:

- `muscleId`를 실제 신체 부위 shape에 연결하지 않는다.
- 전면/후면에 따라 muscle 목록이 필터링되지 않는다.
- `avgActivation`이 이미 percent인지, `0.0~1.0` ratio인지 UI에서 검증하지 않는다.
- `trunk`가 근육 활성도인지 자세 안정성인지 구분하지 않는다.
- No data와 0 활성도가 구분되지 않는다.

### 2.4 실제 2D painter 존재 여부

현재 실제 2D 인체 실루엣 painter는 없다.

확인된 사항:

- `app/lib/ui/stats/tabs/heatmap_tab.dart`에 `CustomPaint`가 없다.
- `FrontBodyHeatmapPainter`, `BackBodyHeatmapPainter` 같은 painter가 없다.
- `app/lib/widgets/avatar/...` 구조도 실제 프로젝트에는 없다.

## 3. 2D 아바타 MVP 방향

### 3.1 제품 방향

MVP 아바타는 귀여운 캐릭터가 아니라 실제 인체 근육도 느낌의 2D 전신 실루엣 기반으로 간다.

통계 탭에서는 다음을 제공한다.

- 전면 전신 아바타
- 후면 전신 아바타
- 측정 데이터가 있는 부위만 히트맵 색상 표시
- 측정되지 않았거나 해당 운동과 무관한 부위는 회색/중립색 표시
- 운동별 필터가 들어오면 관련 부위를 강조하거나 상세 카드에서 확대 표시

### 3.2 색상 정책

실제 값은 `0~100` percent 가 기준이고, 화면에서도 그대로 percent 로 표시한다.

기본 색상은 현재 `AppColors`의 heatmap 색상을 우선 재사용할 수 있다.

| 상태 | 현재 후보 색상 |
| --- | --- |
| No data 또는 미측정 | `AppColors.heatmapInactive` 또는 별도 neutral gray |
| 낮음 | `AppColors.heatmapLow` |
| 보통 | `AppColors.heatmapNormal` |
| 높음 | `AppColors.heatmapHigh` |
| 위험/과활성 | `AppColors.heatmapDanger` |

기획상 5단계 또는 6단계 세분화가 가능하지만, 이 세분화는 센서 정확도 향상을 의미하지 않는다. 사용자가 데이터를 해석하기 쉽게 돕는 시각화 기준이다.

### 3.3 `trunk` 처리

`trunk`는 근육 활성도 색상이 아니라 안정성/자세 지표로 분리한다.

권장 방향:

- 전신 실루엣의 복부/몸통 근육을 빨갛게 칠하는 방식으로 쓰지 않는다.
- 별도 안정성 badge, 중심선 흔들림 indicator, posture overlay, 상세 카드로 표시한다.
- 3D에서도 `trunk`는 특정 근육 mesh 색상보다는 body core stability indicator로 다룬다.

### 3.4 운동별 MVP 표시 범위

| 운동 | 활성도 key | 자세 key | 2D 전면/후면 표시 방향 |
| --- | --- | --- | --- |
| `pushup` | `left_chest`, `right_chest`, `left_triceps`, `right_triceps` | `trunk` | 가슴은 전면, 삼두는 후면 팔 중심. `trunk`는 별도 자세 지표 |
| `bicep_curl` | `left_biceps`, `right_biceps`, `left_forearm`, `right_forearm` | `trunk` | 이두/전완은 전면 팔 중심. `trunk`는 별도 자세 지표 |
| `lateral_raise` | `left_lateral_deltoid`, `right_lateral_deltoid`, `left_upper_trapezius`, `right_upper_trapezius` | `trunk` | 측면 삼각근은 어깨 측면, 상부 승모근은 후면 목/어깨 중심. `trunk`는 별도 자세 지표 |

## 4. 실제 프로젝트 기준 `muscle_map` key 정리

### 4.1 전체 key 목록

| key | 한글 의미 | kind | 대표 운동 | 안정적인 ID로 사용 가능 여부 |
| --- | --- | --- | --- | --- |
| `left_chest` | 왼쪽 대흉근 | activation | `pushup` | 가능 |
| `right_chest` | 오른쪽 대흉근 | activation | `pushup` | 가능 |
| `left_triceps` | 왼쪽 삼두근 | activation | `pushup` | 가능 |
| `right_triceps` | 오른쪽 삼두근 | activation | `pushup` | 가능 |
| `left_biceps` | 왼쪽 이두근 | activation | `bicep_curl` | 가능 |
| `right_biceps` | 오른쪽 이두근 | activation | `bicep_curl` | 가능 |
| `left_forearm` | 왼쪽 전완근 | activation | `bicep_curl` | 가능 |
| `right_forearm` | 오른쪽 전완근 | activation | `bicep_curl` | 가능 |
| `left_lateral_deltoid` | 왼쪽 측면 삼각근 | activation | `lateral_raise` | 가능 |
| `right_lateral_deltoid` | 오른쪽 측면 삼각근 | activation | `lateral_raise` | 가능 |
| `left_upper_trapezius` | 왼쪽 상부 승모근 | activation | `lateral_raise` | 가능 |
| `right_upper_trapezius` | 오른쪽 상부 승모근 | activation | `lateral_raise` | 가능 |
| `trunk` | 몸통 안정성 | postureStability | 공통 | 가능하지만 근육 mesh ID와 분리 권장 |

### 4.2 2D region ID 제안

MVP에서는 `muscle_map` key를 그대로 stable region ID로 사용하는 것이 가장 안전하다.

| `muscle_map` key | 2D front region 후보 | 2D back region 후보 | 비고 |
| --- | --- | --- | --- |
| `left_chest` | `front.left_chest` | 없음 | 전면 대흉근 |
| `right_chest` | `front.right_chest` | 없음 | 전면 대흉근 |
| `left_triceps` | 선택: 팔 외곽 보조 표시 | `back.left_triceps` | 후면 상완 |
| `right_triceps` | 선택: 팔 외곽 보조 표시 | `back.right_triceps` | 후면 상완 |
| `left_biceps` | `front.left_biceps` | 없음 | 전면 상완 |
| `right_biceps` | `front.right_biceps` | 없음 | 전면 상완 |
| `left_forearm` | `front.left_forearm` | 선택: `back.left_forearm` | 전완은 전/후면 모두 표현 가능 |
| `right_forearm` | `front.right_forearm` | 선택: `back.right_forearm` | 전완은 전/후면 모두 표현 가능 |
| `left_lateral_deltoid` | `front.left_lateral_deltoid` | `back.left_lateral_deltoid` | 어깨 측면이라 양쪽 뷰에 표현 가능 |
| `right_lateral_deltoid` | `front.right_lateral_deltoid` | `back.right_lateral_deltoid` | 어깨 측면이라 양쪽 뷰에 표현 가능 |
| `left_upper_trapezius` | 선택: 목/어깨 상단 | `back.left_upper_trapezius` | 후면 중심 표현 권장 |
| `right_upper_trapezius` | 선택: 목/어깨 상단 | `back.right_upper_trapezius` | 후면 중심 표현 권장 |
| `trunk` | 별도 posture overlay | 별도 posture overlay | 근육 활성도 fill과 분리 |

### 4.3 3D mesh/entity ID 제안

3D 전환을 고려해 `muscle_map` key와 mesh/entity ID를 1:1 또는 1:N으로 연결할 수 있게 해야 한다.

권장 규칙:

- 앱 데이터 계약의 stable ID는 `muscle_map` key를 유지한다.
- 3D 모델 내부 mesh/entity ID는 별도 adapter에서 매핑한다.
- 3D asset의 실제 mesh 이름이 바뀌어도 앱 도메인 key는 바꾸지 않는다.

예시:

| stable key | 3D mesh/entity ID 후보 |
| --- | --- |
| `left_chest` | `mesh.muscle.left_chest` |
| `right_chest` | `mesh.muscle.right_chest` |
| `left_triceps` | `mesh.muscle.left_triceps` |
| `right_triceps` | `mesh.muscle.right_triceps` |
| `left_biceps` | `mesh.muscle.left_biceps` |
| `right_biceps` | `mesh.muscle.right_biceps` |
| `left_forearm` | `mesh.muscle.left_forearm` |
| `right_forearm` | `mesh.muscle.right_forearm` |
| `left_lateral_deltoid` | `mesh.muscle.left_lateral_deltoid` |
| `right_lateral_deltoid` | `mesh.muscle.right_lateral_deltoid` |
| `left_upper_trapezius` | `mesh.muscle.left_upper_trapezius` |
| `right_upper_trapezius` | `mesh.muscle.right_upper_trapezius` |
| `trunk` | `mesh.indicator.trunk_stability` 또는 별도 overlay |

## 5. 값 처리 기준

### 5.1 실제 값 범위

스케일 계약(2026-05-18 통일): `muscle_map` 값은 Pi·앱·백엔드·DB·응답 전 구간 `0~100` percent 다.

근거:

- `docs/App_Muscle_Map_Schema.md`는 Pi가 `0~100` percent 로 보낸다고 정의한다.
- Pi `_build_muscle_map_locked`가 0~1 비율을 `*100`해 percent 로 송신한다.
- 백엔드 `_ratio_to_percent`는 percent 입력을 그대로 통과시키고 percent 로 응답한다.
- `muscleMapRatioToPercent`는 폐기됐고, `clampMuscleMapPercent`가 `0~100` clamp 만 한다.
- `SessionResultDto._asDoubleMap`은 `muscle_map` 값을 `double`로 변환한다.

### 5.2 화면 표시

화면에서는 다음 처리를 사용한다(스케일 변환 없음).

```text
percent = clamp(value, 0, 100)
```

통계 API의 `HeatmapTab.data['muscles'][].avgActivation`은 현재 UI에서 바로 `%`처럼 표시된다. 이 값이 API에서 이미 `0~100`으로 오는지, `0.0~1.0`으로 오는지 별도 확인이 필요하다.

### 5.3 missing key 처리

현재 `MuscleMapState.fromValues`는 allowed key가 누락되면 `0`으로 처리한다.

현재 결과:

- missing data: `0`, `inactive`
- 실제 0 활성도: `0`, `inactive`
- 둘을 구분할 수 없음

MVP 기획에서는 "No data는 회색/중립색"이고 "0 활성도는 매우 낮음 또는 inactive"로 해석될 수 있다. 따라서 다음 구현 전에 결정이 필요하다.

결정 후보:

| 안 | 설명 | 장점 | 위험 |
| --- | --- | --- | --- |
| A. 기존 유지 | missing key를 `0`으로 둔다 | 코드 변경 적음 | No data와 실제 0을 구분 못 함 |
| B. painter 입력에서 null 허용 | domain은 유지하고 UI adapter가 `Map<String, double?>`로 변환 | 기존 domain 영향 작음 | adapter가 추가로 필요 |
| C. `MuscleMapEntry.value`를 nullable로 변경 | 도메인부터 No data 표현 | 의미가 명확함 | 영향 범위 큼 |

권장: MVP 1차는 B안이 안전하다. 기존 화면을 깨지 않고 `HeatmapTab` 전용 adapter에서 No data를 표현할 수 있다.

## 6. 2D 구현 범위

### 6.1 painter 후보

실제 프로젝트 구조를 고려하면 painter는 `app/lib/ui/stats` 하위에 두는 것이 자연스럽다.

후보 파일:

- `app/lib/ui/stats/widgets/front_body_heatmap_painter.dart`
- `app/lib/ui/stats/widgets/back_body_heatmap_painter.dart`
- `app/lib/ui/stats/widgets/body_heatmap_view.dart`
- `app/lib/ui/stats/models/body_heatmap_region.dart`

역할:

| 후보 | 역할 |
| --- | --- |
| `FrontBodyHeatmapPainter` | 전면 인체 실루엣과 전면 근육 region fill |
| `BackBodyHeatmapPainter` | 후면 인체 실루엣과 후면 근육 region fill |
| `BodyHeatmapView` | 전면/후면 선택 상태에 따라 painter 교체 |
| `BodyHeatmapRegion` | stable key, value, color, label, view side 연결 |

### 6.2 `HeatmapTab` 연결 위치

현재 `HeatmapTab`에서 교체할 위치는 `SizedBox(height: 390)` 내부의 `Stack`이다.

현재:

- 중앙 `Icons.accessibility_new_rounded`
- `muscles.take(7)` 라벨

MVP 구현 후:

- 중앙 `CustomPaint` 또는 `BodyHeatmapView`
- 전면/후면 선택에 따라 painter 변경
- 기존 라벨은 유지하거나 상세 카드/하단 리스트로 이동
- `data['muscles']`를 painter 입력 모델로 변환하는 adapter 추가

### 6.3 기존 stats/history/session_result 화면 영향 범위

| 화면 | 현재 상태 | 2D 구현 영향 |
| --- | --- | --- |
| `app/lib/ui/stats/widgets/stats_screen.dart` | `HeatmapTab(data: _viewModel.heatmap)` 전달 | 직접 영향 작음. `HeatmapTab` 내부 변경 중심 |
| `app/lib/ui/stats/tabs/heatmap_tab.dart` | placeholder + label UI | 핵심 변경 지점 |
| `app/lib/ui/stats/view_model/stats_viewmodel.dart` | `Map<String, dynamic>? heatmap` 저장 | typed model 도입 시 영향 가능 |
| `app/lib/data/repositories/stats_repository.dart` | weekly heatmap raw map 반환 | typed DTO 도입 시 영향 가능 |
| `app/lib/ui/session_result/widgets/session_result_screen.dart` | 정적 `_MuscleMapCard` placeholder | MVP 통계 탭만 한다면 영향 없음. 세션 결과까지 확장 시 재사용 가능 |
| `app/lib/ui/history/widgets/history_detail_screen.dart` | `hasMuscleMap` 텍스트만 표시 | 상세 히트맵 추가 시 영향 가능 |
| `app/lib/domain/models/muscle_map.dart` | 세션 기반 state 제공 | 세션 결과/히스토리용 입력으로 재사용 가능 |

### 6.4 구현 전 필요한 결정 사항

1. 통계 탭 painter 입력을 `data['muscles']` API 응답 기준으로 만들지, `MuscleMapState`와 같은 domain model로 통일할지 결정한다.
2. `avgActivation` 값 단위가 `0~100`인지 `0.0~1.0`인지 API 기준을 확인한다.
3. No data와 실제 0 활성도를 구분할지 결정한다.
4. `trunk`를 어떤 UI로 분리할지 결정한다. 예: badge, core stability bar, 중심선 overlay.
5. 전면/후면 양쪽에 걸친 근육, 예: `left_lateral_deltoid`, `right_lateral_deltoid`, `left_forearm`, `right_forearm`의 표시 정책을 정한다.
6. 색상 단계를 현재 코드의 4단계 계열로 갈지, 기획의 5~6단계로 확장할지 결정한다.
7. `HeatmapTab`의 고정 label overlay를 유지할지, 하단 리스트/상세 카드로 분리할지 결정한다.

## 7. 3D 전환 범위

### 7.1 제품 기준

3D 아바타는 MVP 필수가 아니라 optional spike로 둔다.

필수 기준:

- 2D fallback은 반드시 유지한다.
- 3D 패키지가 실패하거나 특정 플랫폼에서 불안정해도 통계 탭은 2D로 동작해야 한다.
- 3D는 우선 Android 시연 기준 spike로 검토한다.
- 3D 구현과 패키지 설치는 이번 작업 범위가 아니다.

### 7.2 3D 전환 시 필요한 데이터 계약

3D 렌더러도 2D와 같은 입력 계약을 받아야 한다.

권장 공통 입력:

| 필드 | 설명 |
| --- | --- |
| `exerciseId` | `pushup`, `bicep_curl`, `lateral_raise` |
| `values` | `Map<String, double?>`, key는 `muscle_map` stable key |
| `kindByKey` | activation/postureStability 구분 |
| `basis` | weekly average, latest session 등 기준 |
| `selectedView` | 2D에서는 front/back, 3D에서는 초기 카메라 방향 정도로 사용 |

3D에서는 추가로 다음 adapter가 필요하다.

| adapter | 역할 |
| --- | --- |
| muscle key -> mesh/entity ID | `left_chest` 같은 앱 key를 3D asset 내부 mesh 이름으로 변환 |
| value -> material/color | `0~100` percent 값을 material color 또는 shader parameter로 변환 |
| unsupported mesh fallback | 해당 mesh가 없을 때 회색 또는 무시 처리 |
| posture overlay | `trunk`를 근육 mesh가 아닌 안정성 지표로 표시 |

### 7.3 3D 전환 시 변경될 수 있는 파일 범위

| 범위 | 예상 변경 |
| --- | --- |
| `pubspec.yaml` | 3D 패키지 및 asset 등록. 이번 작업에서는 수정 금지 |
| `app/lib/ui/stats/tabs/heatmap_tab.dart` | 2D/3D renderer 선택 연결 |
| `app/lib/ui/stats/widgets/...` | 2D fallback view와 optional 3D view 분리 |
| `app/lib/ui/stats/models/...` | 2D/3D 공통 activation snapshot 모델 |
| `app/lib/domain/models/muscle_map.dart` | nullable value 또는 no-data 정책을 도메인까지 확장할 경우 변경 가능 |
| `assets/...` | 3D model, texture, material asset 추가 가능 |
| Android/iOS 설정 | 선택 패키지에 따라 WebView, Scene Viewer, native renderer 권한/설정 가능 |

### 7.4 3D 전환 리스크

- Flutter 3D 패키지는 플랫폼별 지원 차이가 크다.
- WebView 기반 패키지는 통합은 쉬울 수 있지만 mesh별 동적 색상 변경이 제한될 수 있다.
- 네이티브/엔진 기반 패키지는 mesh 제어 가능성이 높지만 빌드 리스크와 유지보수 리스크가 커질 수 있다.
- GLB/GLTF asset의 mesh naming이 안정적이지 않으면 앱 key와 연결이 깨진다.
- 3D 모델 품질, polygon 구조, material 분리 여부가 근육별 색상 변경 가능성을 좌우한다.

따라서 제품 구조는 `2D fallback + optional 3D renderer`로 유지해야 한다.

## 8. 최종 결론

14번 작업의 결론은 다음과 같다.

실제 `S14P31C203` 프로젝트에서는 새로운 `SessionRecord`, `ChannelMapping`, `avgCh1/avgCh2/avgCh3` 구조를 만들면 안 된다. 현재 프로젝트에는 이미 `muscle_map` 중심의 데이터 흐름이 있다.

확장해야 할 실제 기준:

- `ExerciseSensorMapping`
- `ExerciseMuscleMapSchema`
- `MuscleMapState`
- `WorkoutSession.muscleMap`
- `SessionResultDto.muscleMap`
- `StatsRepository.getWeeklyHeatmap`
- `StatsViewModel.heatmap`
- `HeatmapTab`

MVP 구현은 `HeatmapTab`의 현재 placeholder를 2D 전면/후면 인체 실루엣 painter로 교체하는 방향이 가장 작고 안전하다. 이때 기존 `muscle_map` key를 stable region ID로 사용하고, `trunk`는 근육 활성도가 아니라 자세 안정성 지표로 분리한다.

3D는 당장 제품 코드에 넣지 않고 optional spike로 분리한다. 추후 3D로 전환하더라도 2D fallback은 유지하고, 2D와 3D가 같은 `muscle_map` stable key 기반 데이터 계약을 공유해야 한다.

