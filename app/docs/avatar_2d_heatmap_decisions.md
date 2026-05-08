# [APP][Avatar] 2D Heatmap 구현 전 결정 사항

## 0. 기준

- 기준 프로젝트: `C:\Users\SSAFY\Desktop\C203\S14P31C203`
- 참고 문서:
  - `app/docs/avatar_2d_to_3d_scope.md`
  - `app/docs/flutter_3d_avatar_package_spike.md`
  - `docs/avatar_project_audit_report.md`
- 이번 문서는 구현 전 결정 사항 정리용이다.
- 앱 코드, `pubspec.yaml`, 패키지, 플랫폼 설정은 수정하지 않는다.

## 1. `avgActivation` 값 처리 정책

결정:

- API의 `avgActivation` 값 단위가 `0.0~1.0` ratio인지 `0~100` percent인지 아직 불확실하므로 `HeatmapTab`용 UI adapter에서 normalize한다.
- `value <= 1.0`이면 ratio로 보고 `percent = value * 100`으로 변환한다.
- `value > 1.0`이면 이미 percent로 보고 `0~100` 범위로 clamp한다.
- 화면과 painter에는 normalize된 percent를 전달한다.

의도:

- 실제 `muscle_map` 도메인 값은 문서와 코드상 `0.0~1.0`이지만, 현재 `HeatmapTab`은 `avgActivation`을 바로 percent처럼 표시하고 있다.
- API 응답 단위가 확정되기 전까지 UI adapter에서 흡수해 기존 화면 리스크를 줄인다.

## 2. No data 처리 정책

결정:

- 기존 domain model은 당장 수정하지 않는다.
- `MuscleMapState.fromValues`의 missing key -> `0` 동작은 이번 구현 전 단계에서 건드리지 않는다.
- `HeatmapTab`용 UI adapter에서 데이터가 없는 `muscle_map` key는 `null`로 취급한다.
- `null`은 회색/중립색으로 표시한다.
- 실제 값 `0`은 No data가 아니라 매우 낮음 또는 inactive로 표시한다.

의도:

- No data와 실제 0 활성도를 구분한다.
- domain model을 nullable로 바꾸는 큰 변경 없이 통계 탭 UI에서 먼저 정책을 적용한다.

## 3. `trunk` 처리 정책

결정:

- `trunk`는 근육 활성도 히트맵 색상으로 칠하지 않는다.
- `trunk`는 `postureStability` 지표로 분리한다.
- MVP에서는 badge 또는 small bar 형태로 표시한다.

표시 방향:

| key | 처리 |
| --- | --- |
| `trunk` | 전면/후면 근육 fill 제외 |
| `trunk` 값 있음 | 자세 안정성 badge 또는 small bar 표시 |
| `trunk` 값 없음 | posture No data 상태 표시 |

## 4. 전면/후면 표시 정책

결정:

| `muscle_map` key | 기본 표시 |
| --- | --- |
| `left_chest` | 전면 |
| `right_chest` | 전면 |
| `left_biceps` | 전면 |
| `right_biceps` | 전면 |
| `left_forearm` | 전면 우선 |
| `right_forearm` | 전면 우선 |
| `left_triceps` | 후면 |
| `right_triceps` | 후면 |
| `left_lateral_deltoid` | 전면 우선, 후면 보조 가능 |
| `right_lateral_deltoid` | 전면 우선, 후면 보조 가능 |
| `left_upper_trapezius` | 후면 |
| `right_upper_trapezius` | 후면 |
| `trunk` | 별도 posture indicator |

MVP 우선순위:

- 전면 view: chest, biceps, forearm, lateral deltoid 중심
- 후면 view: triceps, upper trapezius 중심
- lateral deltoid는 어깨 측면이라 후면 보조 region을 둘 수 있지만 MVP에서는 전면 우선을 기본값으로 둔다.

## 5. 2D 구현 단계

결정:

1. `HeatmapTab` data를 `BodyHeatmapRegion` 모델로 변환하는 UI adapter를 만든다.
2. `FrontBodyHeatmapPainter` / `BackBodyHeatmapPainter` 초안을 만든다.
3. `HeatmapTab`의 현재 `Icons.accessibility_new_rounded` placeholder를 `BodyHeatmapView`로 교체한다.
4. legend와 `trunk` posture badge 또는 small bar를 추가한다.

권장 구현 범위:

| 단계 | 산출물 후보 | 비고 |
| --- | --- | --- |
| 1 | `BodyHeatmapRegion`, adapter | No data/null, percent normalize 담당 |
| 2 | `FrontBodyHeatmapPainter`, `BackBodyHeatmapPainter` | 실제 인체 실루엣 path 초안 |
| 3 | `BodyHeatmapView` | 전면/후면 painter 선택 |
| 4 | legend, posture widget | 색상 해석과 trunk 분리 |

이번 결정:

- painter 구현 전 adapter를 먼저 둔다.
- adapter가 API 응답 불확실성과 No data 정책을 흡수한다.
- domain model은 이후 필요할 때 별도 작업으로 검토한다.

## 6. 3D 관련 결정

결정:

- 3D는 지금 구현하지 않는다.
- 2D 히트맵 완성 후 별도 spike 브랜치에서 `interactive_3d` 중심으로 검증한다.
- 2D fallback은 반드시 유지한다.
- 3D도 같은 `muscle_map` stable key를 입력으로 받아야 한다.

3D 검증 시점에 확인할 항목:

- `left_chest`, `right_chest` 같은 key를 GLB mesh/entity name과 매핑할 수 있는지
- 여러 근육 부위 색상을 동시에 patch할 수 있는지
- No data 부위를 회색으로 유지할 수 있는지
- `trunk`를 근육 mesh가 아닌 posture indicator로 분리할 수 있는지
- Android 실제 기기에서 성능과 빌드가 안정적인지

## 7. 최종 결정 요약

| 항목 | 결정 |
| --- | --- |
| `avgActivation` | UI adapter에서 ratio/percent normalize |
| No data | domain 수정 없이 UI adapter에서 `null` 처리 |
| 실제 0 | No data가 아닌 inactive/매우 낮음 |
| `trunk` | 근육 fill 제외, posture badge/small bar |
| 전면/후면 | key별 기본 view 정책 적용 |
| 2D 구현 순서 | adapter -> painter -> HeatmapTab 연결 -> legend/trunk |
| 3D | 지금 구현하지 않음. 2D 후 별도 spike |
| fallback | 2D fallback 필수 유지 |

