# 근육 히트맵 구현 결정 사항

작성일: 2026-05-11  
브랜치: feature/avatar-heatmap

---

## 1. SVG 자산 선택 — v3 (react-native-body-highlighter 기반)

**결정:** react-native-body-highlighter(MIT, © 2022 ELABBASSI Hicham)의 SVG path를 기반으로 자체 가공한 v3 자산 사용.

**이유:**
- 1차 자체 제작 SVG는 도형 수준의 품질로 데모에 부적합
- v3는 머리카락·손·발·관절 실루엣, 근육 결 디테일까지 포함한 피트니스 앱 수준 자산
- 남녀 분리(4장), anterior/lateral deltoid 분리, back forearm 추가 등 MVP 운동 매핑에 필요한 세분화 완료

**라이선스 처리 의무:**
- `app/assets/licenses/react_native_body_highlighter_MIT.txt` 동봉
- `main.dart`의 `LicenseRegistry`에 등록
- MIT는 저작권 고지와 라이선스 전문 동봉이 의무

---

## 2. 색상 주입 방식 — ColorMapper (SVG string 치환 방식 대신)

**결정:** `flutter_svg`의 `ColorMapper` 인터페이스 사용.

**비교 검토:**

| 방식 | 장점 | 단점 |
|---|---|---|
| SVG string 치환 | 단순, ID 확실 | 매 렌더마다 문자열 파싱 비용, 캐시 어려움 |
| ColorMapper | 렌더 파이프라인 통합, 캐시 효율적 | id 전달 여부가 버전마다 다를 수 있음 |

**PoC 결과 (flutter_svg 2.3.0):**
- 단일 path(`element=path`)와 그룹(`element=g`) 모두 `substitute`가 호출됨
- `<g id="left_rectus_abdominis">` 같은 그룹 근육도 id가 정상 전달됨
- 그룹 fill을 바꾸면 내부 sub-path 전체에 자동 상속 (SVG 표준)
- 하이브리드 방식 불필요

**구현 주의:** ColorMapper는 불변 객체(`const`)로 생성. `regions` 데이터가 바뀔 때만 재생성해야 불필요한 SVG 재파싱 방지.

---

## 3. 후면 좌우 반전 — 별도 처리 없음 (viewer perspective 표준)

**결정:** 코드에서 좌우 반전 로직을 추가하지 않음. `left_*` 데이터는 전후면 모두 화면 왼쪽에 표시.

**배경 — viewer perspective vs. subject perspective:**

| 방식 | 설명 | 예시 |
|---|---|---|
| Subject perspective | 인체가 뒤돌면 왼팔이 화면 오른쪽에 표시 (해부학 교과서/거울) | 후면에서 `left_triceps` → 화면 오른쪽 |
| **Viewer perspective (채택)** | `left_*`는 전후면 모두 화면 왼쪽에 표시 | 후면에서 `left_triceps` → 화면 왼쪽 |

**viewer perspective를 선택한 이유:**
1. **사용자 멘탈 모델** — "내 왼팔 = 화면 왼쪽"으로 고정. 전후면 전환 시 혼란 없음
2. **데이터 일관성** — `left_*` key가 항상 화면 왼쪽. 코드도 단순
3. **SVG 자산 원본 설계** — react-native-body-highlighter의 후면 SVG도 `left_*` id가 화면 왼쪽에 그려져 있음. 의도된 설계
4. **업계 표준** — Strong, Hevy, Fitbod 등 주요 피트니스 앱이 모두 viewer perspective 사용

**사용자가 헷갈릴 경우 대응:** 좌우 반전이 아니라 UI 라벨(안내 문구)로 해결. 데이터 반전은 코드 복잡도만 올리고 혼란을 더 키움.

---

## 4. 색상 정책 — 4단계 + no data / 0 구분

**결정:** 기존 `AppColors` 히트맵 색상 재사용, 4단계 버킷.

| 조건 | 색상 | 비고 |
|---|---|---|
| no data (null) | SVG 원본 neutral gray | ColorMapper에서 originalColor 반환 |
| 측정됐지만 0% | `#D1D5DB` (옅은 회색) | inactive 상태, no data와 시각적 구분 |
| 0% 초과 ~ 20% 미만 | `heatmapLow` (blue) 55% 투명도 | |
| 20% ~ 40% 미만 | `heatmapLow` (blue) | |
| 40% ~ 60% 미만 | `heatmapNormal` (green) | |
| 60% ~ 80% 미만 | `heatmapHigh` (amber) | |
| 80% 이상 | `heatmapDanger` (red) | |

**no data vs. 0% 구분이 중요한 이유:**  
센서가 해당 근육을 측정하지 않은 것(no data)과 측정했는데 활성도가 0인 것(inactive)은 의미가 다름. 둘을 같은 색으로 표시하면 사용자가 "센서 미측정"을 "운동 안 함"으로 오해할 수 있음.

**범례:** 낮음 / 보통 / 높음 / 위험 4단계로 표시.

---

## 5. 근육 라벨 제거

**결정:** SVG 위에 floating 라벨(근육명 / 활성도% / 횟수) 완전 제거.

**이유:**
- 기존 라벨은 구 CustomPainter 기준 하드코딩 좌표로, SVG로 교체 후 위치 불일치
- SVG 자체의 시각적 정보(색상)가 충분하고 라벨이 오히려 가독성을 해침
- 상세 수치는 다른 탭(추세, 밸런스) 또는 운동 결과 화면에서 확인

---

## 6. Gender 연동

**결정:** `UserProfile.gender`('MALE' / 'FEMALE' / 'OTHER')를 `StatsViewModel`에서 로드, `HeatmapTab` → `SvgBodyHeatmapView`로 전달.

- `FEMALE` → `female_{front,back}_body.svg`
- 그 외(`MALE`, `OTHER`, 빈값) → `male_{front,back}_body.svg` (default)
- `OTHER`를 male default로 처리한 것은 임시 결정. 추후 사용자가 선택 가능하게 하거나 별도 중립 자산 도입 가능.

**데이터 흐름:**  
`UserProfileRepository.getProfile()` (캐시 우선) → `StatsViewModel.gender` → `StatsScreen` → `HeatmapTab(gender:)` → `SvgBodyHeatmapView(gender:)`

---

## 7. Gender 연동 — 완료

**데이터 흐름:**  
`UserProfileRepository.getProfile()` (캐시 우선) → `StatsViewModel.gender` → `StatsScreen` → `HeatmapTab(gender:)` → `SvgBodyHeatmapView(gender:)`

**동작 확인:** 여성 계정으로 로그인 시 통계 히트맵에 female SVG 자산이 자동 선택됨을 스크린샷으로 확인.

---

## 8. 기존 CustomPainter 처리

**현재 상태:** `front_body_heatmap_painter.dart`, `back_body_heatmap_painter.dart`, `body_heatmap_view.dart` 파일은 아직 존재하나 호출부 없음.

**향후 처리:** SVG 기반 히트맵 동작 안정화 확인 후 삭제 예정.
