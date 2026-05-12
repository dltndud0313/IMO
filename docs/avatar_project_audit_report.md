# Avatar Project Audit Report

- 작성일: 2026-05-08
- 감사 대상 실제 프로젝트 루트: `C:\Users\SSAFY\Desktop\C203\S14P31C203`
- 감사 범위: 실제 프로젝트 구조 확인, 기존 아바타 문서 정합성 확인, 잘못된 `C:\Users\SSAFY\Desktop\C203\app` 경로 변경사항 확인
- 작업 제한: 구현/복사/삭제/패키지 설치 없음

## 1. 실제 프로젝트 루트 확인 결과

명령 기준 확인 결과:

```text
Get-Location
-> C:\Users\SSAFY\Desktop\C203\S14P31C203

git rev-parse --show-toplevel
-> C:/Users/SSAFY/Desktop/C203/S14P31C203
```

결론:

- 실제 작업 루트는 `C:\Users\SSAFY\Desktop\C203\S14P31C203`가 맞다.
- `C:\Users\SSAFY\Desktop\C203\app`는 이 git repository 내부가 아니다.
- 이후 구현은 반드시 `S14P31C203` 내부에서만 진행해야 한다.

## 2. Git Status 요약

감사 시작 시점의 `S14P31C203` `git status --short` 결과는 비어 있었다.

결론:

- 실제 프로젝트 git worktree는 감사 시작 시점 기준 clean 상태였다.
- 이번 감사 산출물은 `S14P31C203/docs/avatar_project_audit_report.md`다.

참고:

- `C:\Users\SSAFY\Desktop\C203\app`에서 `git rev-parse --show-toplevel` 실행 시 `fatal: not a git repository`가 발생했다.
- 따라서 잘못된 `app` 경로의 변경 여부는 git status로 판단할 수 없고, 실제 파일 존재 여부와 timestamp 기준으로만 확인 가능하다.

주의:

- 감사 보고서 작성 중 도구 기준 경로 문제로 `C:\Users\SSAFY\Desktop\C203\docs\avatar_project_audit_report.md`도 생성된 것이 확인되었다.
- 이 상위 경로 파일은 실제 프로젝트 산출물이 아니며, 사용자 승인 전 삭제/이동하지 않는다.

## 3. 실제 app/lib 구조 요약

실제 프로젝트의 `app/lib` 1차 구조:

```text
app/lib
  config
  data
  domain
  ui
  main.dart
```

대표 구조:

- `app/lib/domain/models/`
  - `exercise_type.dart`
  - `exercise_sensor_mapping.dart`
  - `muscle_map.dart`
  - `muscle_map_schema.dart`
  - `workout_session.dart`
- `app/lib/data/dto/`
  - `session_result_dto.dart`
- `app/lib/data/repositories/`
  - `stats_repository.dart`
  - `session_history_repository.dart`
  - `workout_repository.dart`
- `app/lib/ui/stats/`
  - `widgets/stats_screen.dart`
  - `widgets/stats_tab_bar.dart`
  - `tabs/heatmap_tab.dart`
  - `tabs/balance_tab.dart`
  - `tabs/trend_tab.dart`
  - `view_model/stats_viewmodel.dart`
- `app/lib/ui/session_result/widgets/session_result_screen.dart`
- `app/lib/ui/history/widgets/history_detail_screen.dart`

실제 프로젝트는 이전에 작업했던 루트 `app`처럼 `app/lib/models`, `app/lib/widgets/avatar`, `app/lib/screens` 중심 구조가 아니다. Clean architecture에 가까운 `domain/data/ui` 구조다.

## 4. 요청된 파일 존재 여부

요청 목록을 실제 `S14P31C203` 기준으로 확인한 결과:

| 파일 | 실제 프로젝트 존재 여부 |
|---|---|
| `app/lib/widgets/avatar/avatar_view.dart` | 없음 |
| `app/lib/widgets/avatar_painter.dart` | 없음 |
| `app/lib/widgets/avatar/avatar_types.dart` | 없음 |
| `app/lib/models/exercise.dart` | 없음 |
| `app/lib/mock/mock_data.dart` | 없음 |
| `app/lib/models/session_record.dart` | 없음 |
| `app/lib/db/database_helper.dart` | 없음 |
| `app/lib/screens/exercise_stats_screen.dart` | 없음 |
| `app/lib/screens/history_detail_screen.dart` | 없음 |
| `app/lib/screens/result_screen.dart` | 없음 |

결론:

- 이전 문서/구현에서 전제로 삼은 파일 경로는 실제 프로젝트와 일치하지 않는다.
- 실제 프로젝트의 대응 파일은 아래처럼 다르다.

| 이전 전제 | 실제 프로젝트 대응 후보 |
|---|---|
| `Exercise`, `ChannelMapping`, `mock_data` | `domain/models/exercise_type.dart`, `domain/models/exercise_sensor_mapping.dart`, `ui/workout_setup/widgets/exercise_catalog_data.dart` |
| `SessionRecord.avgCh1/avgCh2/avgCh3` | `WorkoutSession`, `SessionResultDto`, `muscleMap: Map<String, double>` |
| `exercise_stats_screen.dart` | `ui/stats/widgets/stats_screen.dart`, `ui/stats/tabs/heatmap_tab.dart` |
| `history_detail_screen.dart` | `ui/history/widgets/history_detail_screen.dart` |
| `result_screen.dart` | `ui/session_result/widgets/session_result_screen.dart` |
| `AvatarPainter`, `AvatarView` | 현재 직접 대응 없음 |

## 5. 실제 프로젝트의 현재 히트맵/근육 데이터 구조

실제 프로젝트는 이미 `muscle_map` 중심 구조를 갖고 있다.

### 5.1 `exercise_sensor_mapping.dart`

실제 운동별 센서 매핑은 CH1~CH3이 아니라 EMG1~EMG4 및 IMU1~IMU3 기준이다.

대표 key:

- `pushup`
  - `left_chest`
  - `right_chest`
  - `left_triceps`
  - `right_triceps`
  - `trunk`
- `bicep_curl`
  - `left_biceps`
  - `right_biceps`
  - `left_forearm`
  - `right_forearm`
  - `trunk`
- `lateral_raise`
  - `left_lateral_deltoid`
  - `right_lateral_deltoid`
  - `left_upper_trapezius`
  - `right_upper_trapezius`
  - `trunk`

### 5.2 `muscle_map_schema.dart`

실제 프로젝트는 `ExerciseMuscleMapSchema`와 `MuscleMapKeyDefinition`을 통해 운동별 허용 key와 표시명을 정의한다.

현재 level 분류:

```text
MuscleMapStatus: inactive, low, normal, high, danger
MuscleActivationLevel: inactive, low, normal, high, danger
```

현재 값 범위:

- `muscle_map` value는 `0.0~1.0` 비율값으로 해석된다.
- `muscleMapRatioToPercent`에서 percent로 변환한다.

### 5.3 `muscle_map.dart`

`MuscleMapState.fromValues`는 운동별 allowed key를 기반으로 entry를 만든다.

중요한 차이:

- 현재 `includeMissingKeys = true`일 때 누락된 key는 `values[key] ?? 0`으로 처리된다.
- 즉 현재 실제 코드는 "No data"를 `null`이 아니라 `0`처럼 표시할 수 있다.
- 신규 기획의 "No data는 0이 아니라 null" 기준과 충돌한다.

### 5.4 `heatmap_tab.dart`

실제 통계 탭의 heatmap UI는 이미 존재한다.

현재 동작:

- `widget.data?['muscles']` 목록을 읽는다.
- front/back segmented control이 있다.
- 중앙에는 `Icons.accessibility_new_rounded` placeholder가 있다.
- 실제 전면/후면 인체 근육 실루엣 painter는 없다.
- label은 `muscleName`, `muscleId`, `avgActivation`, `sessionCount`를 표시한다.
- legend는 낮음/보통/높음 3단계다.

결론:

- 실제 프로젝트는 "아바타가 전혀 없음"이 아니라, 통계 heatmap placeholder와 muscle_map 도메인 모델이 이미 있다.
- 다음 구현은 새 `SessionRecord + ChannelMapping` 모델을 도입하기보다, 기존 `MuscleMapState`, `ExerciseSensorMapping`, `HeatmapTab`을 확장하는 방향이어야 한다.

## 6. 기존 문서 3개 위치 및 정합성

확인 대상 문서:

- `docs/avatar_2d_to_3d_scope.md`
- `docs/avatar_muscle_mapping.md`
- `docs/flutter_3d_avatar_package_spike.md`

실제 `S14P31C203/docs`에는 위 3개 파일이 없다.

발견 위치:

| 파일 | 발견 위치 |
|---|---|
| `avatar_2d_to_3d_scope.md` | `C:\Users\SSAFY\Desktop\C203\docs\avatar_2d_to_3d_scope.md` |
| `avatar_muscle_mapping.md` | `C:\Users\SSAFY\Desktop\C203\docs\avatar_muscle_mapping.md` |
| `flutter_3d_avatar_package_spike.md` | `C:\Users\SSAFY\Desktop\C203\docs\flutter_3d_avatar_package_spike.md` |

즉 기존 문서 3개는 실제 프로젝트의 `docs`가 아니라 상위 `C203/docs`에 작성되어 있다.

### 6.1 실제 코드와 일치하는 부분

기획/제품 방향 수준에서 일치하는 부분:

- MVP는 2D 전면/후면 근육 히트맵 중심이라는 방향은 실제 `ui/stats/tabs/heatmap_tab.dart`의 front/back segmented control과 부분적으로 맞다.
- 3D는 optional spike로 두고 2D fallback을 유지한다는 방향은 실제 프로젝트에 아직 3D 의존성이 없으므로 안전한 접근이다.
- `model_viewer_plus`, `flutter_3d_controller`, `interactive_3d` 중심 spike 검토는 구현 전 조사 문서로는 재사용 가능하다.
- `playx_3d_scene`을 Android-only 실험 후보이지만 제품 코드 비추천으로 둔 판단은 실제 프로젝트에도 적용 가능하다.
- "측정된 부위만 색상 표시, 나머지는 중립색" 방향은 실제 `muscle_map` key 기반 구조와 잘 맞는다.

### 6.2 실제 코드와 다른 부분

구조/파일 경로 기준 불일치:

- 문서는 `app/lib/widgets/avatar/avatar_view.dart`, `avatar_painter.dart`, `avatar_types.dart`를 전제로 하지만 실제 프로젝트에는 없다.
- 문서는 `app/lib/models/exercise.dart`, `ChannelMapping`, `mock_data.dart`를 전제로 하지만 실제 프로젝트에는 없다.
- 문서는 `SessionRecord.avgCh1/avgCh2/avgCh3` 기반 adapter를 전제로 하지만 실제 프로젝트는 `WorkoutSession.muscleMap` 및 `SessionResultDto.muscleMap` 기반이다.
- 문서는 `app/lib/screens/exercise_stats_screen.dart`, `history_detail_screen.dart`, `result_screen.dart`를 전제로 하지만 실제 경로는 `ui/stats`, `ui/history`, `ui/session_result`이다.

운동/채널 매핑 기준 불일치:

- 문서는 `pushup`, `curl`, `lateral_raise`의 CH1~CH3 매핑을 기준으로 한다.
- 실제 프로젝트는 `pushup`, `bicep_curl`, `lateral_raise`와 EMG1~EMG4 + IMU1~IMU3 기준이다.
- 실제 `bicep_curl` id는 `curl`이 아니라 `bicep_curl`이다.
- 실제 `pushup`은 `left_chest`, `right_chest`, `left_triceps`, `right_triceps`처럼 좌우 key가 이미 분리되어 있다.
- 실제 `lateral_raise`는 `left_lateral_deltoid`, `right_lateral_deltoid`, `left_upper_trapezius`, `right_upper_trapezius`처럼 좌우 key가 이미 분리되어 있다.

값 범위/No data 기준 불일치:

- 문서는 `0~100` 값을 전제로 한다.
- 실제 `muscle_map`은 문서와 코드상 `0.0~1.0` 비율값을 전제로 한다.
- 문서는 No data를 `null`로 처리하자고 한다.
- 실제 `MuscleMapState.fromValues`는 누락된 allowed key를 `0`으로 채운다.

결론:

- 기존 문서 3개는 실제 프로젝트 기준으로 그대로 신뢰하면 안 된다.
- 제품 방향과 3D 패키지 조사 일부는 재사용 가능하지만, 코드 구조/모델/매핑/경로는 실제 프로젝트 기준으로 다시 작성해야 한다.

## 7. 잘못된 경로 `C:\Users\SSAFY\Desktop\C203\app` 발견 내용

`C:\Users\SSAFY\Desktop\C203\app`는 git repository가 아니다.

확인된 잘못된 경로의 구현 파일:

| 파일 | 상태 |
|---|---|
| `C:\Users\SSAFY\Desktop\C203\app\lib\models\avatar_activation.dart` | 존재 |
| `C:\Users\SSAFY\Desktop\C203\app\lib\models\avatar_muscle_mapping.dart` | 존재 |
| `C:\Users\SSAFY\Desktop\C203\app\lib\services\avatar_activation_mapper.dart` | 존재 |
| `C:\Users\SSAFY\Desktop\C203\app\test\avatar_activation_mapper_test.dart` | 존재 |

확인된 잘못된 위치의 문서:

| 파일 | 상태 |
|---|---|
| `C:\Users\SSAFY\Desktop\C203\docs\avatar_2d_to_3d_scope.md` | 존재 |
| `C:\Users\SSAFY\Desktop\C203\docs\avatar_muscle_mapping.md` | 존재 |
| `C:\Users\SSAFY\Desktop\C203\docs\flutter_3d_avatar_package_spike.md` | 존재 |
| `C:\Users\SSAFY\Desktop\C203\docs\avatar_implementation_notes.md` | 존재 |
| `C:\Users\SSAFY\Desktop\C203\docs\avatar_project_audit_report.md` | 존재하지만 실제 프로젝트 산출물이 아님 |

확인 결과:

- `C:\Users\SSAFY\Desktop\C203\app\docs`에는 위 3개 avatar 문서가 없었다.
- avatar 문서들은 `C:\Users\SSAFY\Desktop\C203\docs`에 있었다.
- 구현 파일들은 `C:\Users\SSAFY\Desktop\C203\app\lib`와 `C:\Users\SSAFY\Desktop\C203\app\test`에 있었다.

## 8. 이관해도 되는 내용

바로 복사하지 말고, 실제 프로젝트 구조에 맞춰 재작성한다는 전제에서 이관 가능한 내용:

### 8.1 개념/기획

- 2D 전면/후면 근육 히트맵을 MVP로 두는 방향.
- 3D는 optional spike로 두고 2D fallback을 유지하는 방향.
- 측정된 부위만 색상 표시하고 미측정/무관 부위는 중립색으로 두는 방향.
- 3D 후보를 `model_viewer_plus`, `flutter_3d_controller`, `interactive_3d` 중심으로 검토하는 방향.
- `playx_3d_scene`은 Android-only 실험 후보로만 두고 제품 코드 후보로 제외하는 판단.

### 8.2 코드 아이디어

- `AvatarActivationSnapshot` 같은 중간 view model 개념.
- `No data`와 측정된 `0`을 구분해야 한다는 원칙.
- fallback renderer와 optional 3D renderer가 같은 데이터 계약을 공유해야 한다는 원칙.

단, 실제 프로젝트에서는 이름과 위치를 아래처럼 바꿔야 한다.

| 잘못된 경로 코드 기준 | 실제 프로젝트에 맞는 방향 |
|---|---|
| `app/lib/models/avatar_activation.dart` | `app/lib/domain/models/...` 또는 `app/lib/ui/stats/...` 하위 모델로 재설계 |
| `SessionRecord.avgCh1/avgCh2/avgCh3` | `WorkoutSession.muscleMap` 또는 API heatmap `muscles` |
| `Exercise/ChannelMapping` | `ExerciseSensorMapping`, `ExerciseMuscleMapSchema` |
| `pushup/curl/lateral_raise CH1~CH3` | `pushup/bicep_curl/lateral_raise muscle_map key` |

## 9. 이관하면 위험한 파일

아래 파일은 실제 프로젝트에 바로 복사하면 위험하다.

| 파일 | 위험 이유 |
|---|---|
| `C:\Users\SSAFY\Desktop\C203\app\lib\models\avatar_activation.dart` | 독립 모델 자체는 단순하지만 실제 프로젝트의 `MuscleMapState`, `WorkoutSession`, `HeatmapTab`과 연결되지 않는다. 위치도 실제 구조와 맞지 않는다. |
| `C:\Users\SSAFY\Desktop\C203\app\lib\models\avatar_muscle_mapping.dart` | CH1~CH3, `curl`, `avgCh` 기준이라 실제 EMG1~EMG4, `bicep_curl`, 좌우 muscle_map key와 충돌한다. |
| `C:\Users\SSAFY\Desktop\C203\app\lib\services\avatar_activation_mapper.dart` | `Exercise`, `SessionRecord`, `avgCh1/2/3`에 의존하므로 실제 프로젝트에서 컴파일되지 않는다. |
| `C:\Users\SSAFY\Desktop\C203\app\test\avatar_activation_mapper_test.dart` | `flutter_application_1` package import와 잘못된 mock 구조에 의존한다. 실제 app package는 `imo`다. |

결론:

- 잘못된 `app` 경로의 구현 파일은 "참고 자료"로만 보고, 실제 프로젝트에는 직접 복사하지 않는다.

## 10. 다시 작성해야 하는 문서

실제 프로젝트 기준으로 다시 작성해야 할 문서:

| 문서 | 조치 |
|---|---|
| `avatar_2d_to_3d_scope.md` | `S14P31C203/docs` 안에 실제 `domain/data/ui` 구조 기준으로 재작성 필요 |
| `avatar_muscle_mapping.md` | CH1~CH3 기준이 아니라 `exercise_sensor_mapping.dart`와 `muscle_map_schema.dart` 기준으로 재작성 필요 |
| `flutter_3d_avatar_package_spike.md` | 패키지 후보 내용은 재사용 가능하나 실제 제품 구조/2D fallback 위치를 `ui/stats/tabs/heatmap_tab.dart` 기준으로 업데이트 필요 |
| `avatar_implementation_notes.md` | 잘못된 구현 기록이므로 실제 프로젝트 기준으로 새 implementation notes 작성 필요 |

이미 실제 프로젝트에 있는 참고 문서:

- `S14P31C203/docs/App_Sensor_Placement_Map.md`
- `S14P31C203/docs/App_Muscle_Map_Schema.md`
- `S14P31C203/docs/Flutter App Architecture.md`

새 문서는 위 3개와 충돌하지 않게 작성해야 한다.

## 11. 다음 구현 전에 필요한 조치

1. `S14P31C203/docs`에 실제 프로젝트 기준 avatar scope 문서를 새로 작성한다.
2. `App_Sensor_Placement_Map.md`와 `App_Muscle_Map_Schema.md`의 `muscle_map` key를 기준으로 전면/후면 히트맵 mapping을 정의한다.
3. 기존 `MuscleMapState.fromValues`의 missing key 처리 정책을 결정한다.
   - 현재: missing key -> `0`
   - 신규 기획: missing key -> `No data/null`
4. `HeatmapTab`이 받는 API `data['muscles']` 구조와 `MuscleMapState` 구조 중 어느 쪽을 2D painter 입력으로 쓸지 결정한다.
5. `pushup`, `bicep_curl`, `lateral_raise`의 좌우 muscle_map key를 전면/후면 2D detail region에 매핑한다.
6. `trunk`는 근육 활성도가 아니라 자세 안정성/보상 지표이므로 근육 히트맵 색상과 별도 처리한다.
7. 3D spike 문서는 `interactive_3d`의 mesh/entity 색상 patch 가능성을 실제 `left_chest`, `right_chest` 같은 key와 연결하는 방식으로 재작성한다.
8. 잘못된 `C:\Users\SSAFY\Desktop\C203\app` 파일은 사용자가 승인하기 전에는 삭제/복사하지 않는다.

## 12. 최종 결론

실제 프로젝트 `S14P31C203`는 이전 작업에서 전제로 삼은 루트 `app` 프로젝트와 구조가 다르다. 실제 프로젝트에는 이미 `muscle_map`, `exercise_sensor_mapping`, `HeatmapTab`이 존재하므로, 다음 구현은 `SessionRecord.avgCh1/avgCh2/avgCh3 + ChannelMapping` 방식이 아니라 실제 `WorkoutSession.muscleMap`, `ExerciseSensorMapping`, `ExerciseMuscleMapSchema`, `ui/stats/tabs/heatmap_tab.dart`를 기준으로 다시 설계해야 한다.

잘못된 경로에 만들어진 구현 파일들은 직접 이관하면 위험하다. 개념만 참고하고 실제 프로젝트 구조에 맞게 새로 작성하는 것이 안전하다.
