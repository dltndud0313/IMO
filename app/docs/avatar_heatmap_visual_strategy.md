# [APP][Avatar] 2D 근육 히트맵 시각화 전략

**작성일**: 2026-05-08  
**기준 경로**: `C:\Users\SSAFY\Desktop\C203\S14P31C203`  
**현재 구현 단계**: 21번 작업 완료 (CustomPainter 기반 초안 → HeatmapTab 통합)

---

## 1. 현재 구현 결과 평가

### 1.1 현재 상태 요약

**기능 구현 진행도**:
- ✅ 근육 데이터 모델 (`BodyHeatmapRegion`)
- ✅ 데이터 어댑터 (`buildBodyHeatmapRegionsFromData`)
- ✅ CustomPainter 기반 렌더링 (`FrontBodyHeatmapPainter`, `BackBodyHeatmapPainter`)
- ✅ 전면/후면 전환 UI 통합 (`HeatmapTab`)
- ✅ 활성도 색상 범례 및 근육 레이블

**기술 현황**:
```
구조: CustomPainter → Canvas.drawRRect() → 단순 도형 조합
신체 표현: 원형 + 둥근 사각형 기본 도형
근육 영역: 하드코딩된 RRect 좌표
색상 처리: percent 값 기반 5단계 색상 매핑
```

### 1.2 시각적 부족함의 구체적 원인

**현재 CustomPainter 방식의 한계**:

1. **신체 실루엣의 부자연스러움**
   - 실제 인체가 아닌 로봇/기하학적 도형으로 표현
   - 사용자가 근육 부위를 직관적으로 인식하기 어려움
   - 단순 도형 조합으로는 근육 경계가 모호함

2. **근육 영역 표현의 한계**
   - 각 근육을 단일 RRect로 표현하여 근육 형태가 정확하지 않음
   - 예: 전면 chest를 좌우 2개 RRect로 분리했으나, 실제 흉근은 더 복잡한 형태
   - 팔 근육(biceps, forearm, triceps) 구분이 시각적으로 불명확
   - 어깨(deltoid) 부위가 축소되어 활성도 표현이 약함

3. **사용자 인식도 부족**
   - 아이콘 기반 placeholder에서 단순 도형 기반으로 변경되었지만, 여전히 "실제 근육 히트맵"처럼 보이지 않음
   - 피트니스 앱의 참고 이미지(실제 인체 실루엣 + 근육 색상)와 비교하면 전문성 부족
   - 통계 기능을 지원한다는 신뢰도 감소

4. **확장성 문제**
   - 새로운 근육 영역 추가 시 RRect 좌표를 하드코딩해야 함
   - 근육 경계선이 명확하지 않아 색상 overlay의 효과가 제한적
   - 고도화 가능성은 있지만 코드 복잡도 증가

### 1.3 참고 이미지 기준의 요구사항

**목표 수준**:
- 실제 인체 형태의 realistic 신체 실루엣
- 근육 경계가 명확하게 구분되는 영역 표현
- 각 근육 부위에 색상이 자연스럽게 overlay
- 전면/후면 전환 시에도 일관성 있는 신체 표현
- 트레이닝 결과를 시각적으로 직관적으로 전달

---

## 2. 현재 CustomPainter 방식의 기술적 평가

### 2.1 구조 분석

**장점**:
- 의존성 없음 (Flutter 기본 Canvas만 사용)
- 번들 크기 영향 없음
- 응답성 우수 (렌더링이 빠름)
- 완전한 프로그래밍 제어 가능
- 개발 초기 단계에서 빠른 프로토타이핑

**근본적 한계**:
- 수동으로 그려야 할 path/geometry가 매우 복잡함
- 근육 해부학적 정확도를 코드로 구현하기 어려움
- 미세한 조정(픽셀 수준)이 많이 필요함
- Bezier curve 조합으로 유기적 형태 구현 가능하지만 유지보수 복잡도 급증
- 비전공자가 작성하면 부정확한 신체 형태 위험

### 2.2 현재 코드 복잡도 분석

**현재 파일 구조**:
```
FrontBodyHeatmapPainter: ~160 lines
  - _BodyGuide: ~120 lines (하드코딩된 좌표 모음)
  - _paintSilhouette(): 기본 신체 outline
  - _paintRegion(): 근육 영역 색칠
  - _heatmapColorForPercent(): 색상 매핑

BackBodyHeatmapPainter: 유사 구조
```

**근육 영역 정의 방식**:
```dart
RRect get chestLeft => _rounded(
  centerX - 56 * scale,
  top + 105 * scale,
  52 * scale,
  58 * scale,
  16 * scale,
);
// 13개 근육 부위 × 2개(좌/우) 또는 해부학적 단위별로 반복
```

**고도화 난이도 추정**:
- 현재 수준 (단순 도형): 대략 정확함
- 근육 형태 개선 (복잡 path): **난이도 급증** (Bezier curve 다중 조합)
- 애니메이션 추가: 중간 수준
- 반응형 스케일링: 이미 구현됨

### 2.3 현재 방식이 부적합한 이유

**결론: CustomPainter 고도화는 ROI가 맞지 않음**

| 측면 | 평가 |
|------|------|
| 시각 퀄리티 상승폭 | 제한적 (좋아봐야 "괜찮은 도형") |
| 개발 시간 | 증가분 > 효과 |
| 유지보수 복잡도 | 지수적 증가 |
| 근육 정확도 | 해부학 지식 필요 |
| 버그 위험 | 좌표 수정 시 전체 레이아웃 영향 |
| 확장성 | 근육 추가 어려움 |

**비추천 이유**:
- CustomPainter로 근육 히트맵을 "제대로" 구현하려면, 결국 복잡한 path geometry를 모두 하드코딩해야 함
- 이는 PNG/SVG asset을 사용하는 것보다 더 많은 코드를 요구하고, 유지보수는 더 어려움
- 현재 도형 기반 구현에서 한 단계 진화시키더라도, 결국 asset 기반 방식으로 마이그레이션할 가능성이 높음

---

## 3. 대안 비교 분석

### 3.1 옵션 1: PNG Asset 기반 방식

**구현 개념**:
- 디자이너가 준비한 **전면/후면 신체 실루엣 PNG** (흰 배경, 검은 선)
- Flutter에서 `Image.asset()` 또는 `ui.Image`로 렌더링
- 각 근육 영역을 `muscle_map` key 기준으로 색상 overlay
- Overlay 방식:
  - Canvas에 PNG 그린 후, 근육 영역별로 반투명 색상 rectangle overlay
  - 또는 shader 기반 색상 치환

**장점**:
- ✅ 시각 퀄리티 **우수** (realistic 신체 형태)
- ✅ 구현 난이도 **낮음** (asset 준비 후 overlay 로직만)
- ✅ 근육 경계 명확 (디자이너가 그린 대로)
- ✅ 확장성 **중상** (새 근육 추가 시 asset 재작성 + overlay 코드 추가)
- ✅ 성능 우수 (PNG 렌더링 + 단순 overlay)
- ✅ 저작권 관리 용이 (내부 자산)

**단점**:
- ❌ 사람이 준비할 작업: **PNG 2개 (전면/후면)** + 근육 영역 좌표 정의
- ❌ 반응형 스케일링 시 image quality 변동 가능
- ❌ 근육 영역별 정확한 좌표/shape 정의 필요
- ❌ PNG 크기가 증가하면 번들 크기 영향

**구현 난이도**: ⭐⭐ (중간)  
**시각 퀄리티**: ⭐⭐⭐⭐⭐ (최고)  
**MVP 적합성**: ⭐⭐⭐⭐ (매우 적합)

**구현 스케치**:
```dart
class BodyHeatmapPainter extends CustomPainter {
  final ui.Image bodyImage;  // PNG 이미지
  final List<BodyHeatmapRegion> regions;
  final Map<String, Rect> muscleRegionBounds;  // 근육별 overlay 영역
  
  paint(Canvas canvas, Size size) {
    // 1. PNG 그리기
    canvas.drawImage(bodyImage, Offset.zero, Paint());
    
    // 2. 근육별 overlay
    for (final region in regions) {
      final rect = muscleRegionBounds[region.key];
      if (rect != null) {
        canvas.drawRect(
          rect,
          Paint()
            ..color = heatmapColor(region.percent)
            ..blendMode = BlendMode.color,  // 또는 다른 blend mode
        );
      }
    }
  }
}
```

### 3.2 옵션 2: SVG Asset 기반 방식

**구현 개념**:
- 디자이너가 준비한 **전면/후면 SVG** (각 근육을 별도 path/group으로 정의)
- SVG 파일에서 각 근육 path에 `id` 또는 `data-key` 속성 부여
  - 예: `<path id="left_chest" d="M ... Z" />`
  - 예: `<group data-muscle-key="left_biceps" />`
- Flutter SVG 패키지 활용 또는 SVG → Flutter code 변환
- 근육 key별로 SVG path 색상 변경

**장점**:
- ✅ 시각 퀄리티 **우수** (해상도 무관 무한 확대 가능)
- ✅ 구현 난이도 **낮음** (SVG path 인식 후 색상 변경만)
- ✅ 근육 경계 명확 (SVG path 기준)
- ✅ 확장성 **우수** (새 근육 추가 시 SVG path만 추가)
- ✅ 벡터 기반이므로 반응형 확대 적합
- ✅ 해상도 무관

**단점**:
- ❌ 패키지 의존 (`flutter_svg` 필요)
- ❌ 사람이 준비할 작업: **SVG 2개** + 근육별 path id 정의
- ❌ SVG 복잡도 증가 시 렌더링 성능 저하 가능
- ❌ path 구조 변경 시 코드 수정 필요
- ❌ SVG 파일 크기 커질 수 있음

**구현 난이도**: ⭐⭐ (중간~하단)  
**시각 퀄리티**: ⭐⭐⭐⭐⭐ (최고)  
**MVP 적합성**: ⭐⭐⭐⭐ (매우 적합, 단 패키지 추가)

**구현 스케치**:
```dart
class BodyHeatmapSvgPainter extends CustomPainter {
  final DrawableRoot svgDocument;  // flutter_svg 기반
  final List<BodyHeatmapRegion> regions;
  
  paint(Canvas canvas, Size size) {
    // 1. SVG 렌더링
    svgDocument.draw(canvas, size);
    
    // 2. 각 근육 path 색상 변경
    for (final region in regions) {
      final element = _findSvgElementByKey(svgDocument, region.key);
      if (element != null) {
        element.style?.fill = SvgColor(heatmapColor(region.percent));
      }
    }
    
    svgDocument.draw(canvas, size);
  }
}
```

### 3.3 옵션 3: PNG/SVG + 정적 실루엣 절충안 (권장)

**구현 개념**:
- PNG 또는 SVG 신체 실루엣을 기반으로 함
- **MVP 단계**: 근육별 색상 overlay만 적용 (경계선 미표시)
- **이후 단계**: 근육 경계 세세한 표현 추가

**특징**:
- PNG/SVG 선택은 팀의 기술 방향에 따라 결정
- MVP에서는 "신체 실루엣 + 색상"만으로 충분
- 근육 경계 표현은 22번 이후 작업으로 분리

**MVP 레벨**:
```
신체 배경: PNG/SVG 실루엣 (회색 또는 밝은 색)
근육 overlay: muscle_map key별 색상 (low/normal/high)
레이블: 기존 근육 레이블 유지
범례: 현재 그대로 유지
```

**이후 고도화 (추가 작업)**:
```
근육 경계선: SVG 근육 그룹별 테두리 추가
근육 명칭: 근육 부위별 텍스트 overlay
상세 색상: 근육별 세부 음영 처리
```

---

## 4. 3가지 선택지의 최종 평가표

| 평가 항목 | CustomPainter 고도화 | PNG Asset | SVG Asset |
|----------|-------------------|-----------|-----------|
| **구현 난이도** | ⭐⭐⭐⭐ (높음) | ⭐⭐ (낮음) | ⭐⭐ (낮음) |
| **시각 퀄리티** | ⭐⭐ (낮음) | ⭐⭐⭐⭐⭐ (우수) | ⭐⭐⭐⭐⭐ (우수) |
| **이번 MVP 적합성** | ⭐ (부적합) | ⭐⭐⭐⭐ (매우 적합) | ⭐⭐⭐⭐ (매우 적합) |
| **발표/시연용** | ⭐ (낮음) | ⭐⭐⭐⭐⭐ (매우 적합) | ⭐⭐⭐⭐⭐ (매우 적합) |
| **Codex/Claude 구현 가능** | ⭐⭐ (가능, 제한적) | ⭐⭐⭐⭐⭐ (완전 자동화) | ⭐⭐⭐⭐ (거의 자동화) |
| **사람이 준비할 것** | 복잡한 path 코드 | 2개 PNG + 좌표표 | 2개 SVG (path id) |
| **3D 호환성** | 낮음 | 중간 (텍스처로 참고 가능) | 높음 (3D mesh와 유사 구조) |
| **저작권/라이선스** | 없음 | 내부 자산만 필요 | 내부 자산만 필요 |
| **패키지 추가** | 없음 | 없음 | flutter_svg 필요 |
| **성능** | ⭐⭐⭐⭐ (매우 우수) | ⭐⭐⭐⭐ (우수) | ⭐⭐⭐ (중상) |
| **번들 크기 영향** | 없음 | 적음 (PNG 10~30KB) | 적음 (SVG 5~15KB) |
| **근육 경계 명확성** | 낮음 | 높음 | 높음 |
| **확장성** | 낮음 (좌표 하드코딩) | 중간 (overlay 영역 추가) | 높음 (path 추가) |
| **유지보수 복잡도** | 높음 | 낮음 | 낮음 |

---

## 5. MVP 권장안

### 5.1 단기 (이번 시연 포함 ~ 2주)

**결론: PNG Asset 기반 방식 채택**

**이유**:
1. **시각 퀄리티 개선이 즉각적** - 현재 도형 기반 → realistic 신체 실루엣
2. **구현 난이도 최소** - Asset 준비 후 overlay 로직만 추가
3. **발표/시연 효과 우수** - "근육 히트맵"이 한눈에 인식됨
4. **패키지 추가 불필요** - 기존 의존성으로 구현 가능
5. **다음 3D 작업과 호환** - 2D texture로 참고 가능

**구현 순서**:
1. 디자이너: 전면/후면 신체 실루엣 PNG 2개 준비
   - 크기: 390x390px (현재 HeatmapTab 높이 기준)
   - 배경: 투명 또는 흰색 (overlay 고려)
   - 해상도: 1x (기본) + @2x (옵션)

2. 구현자: 근육별 overlay 영역 정의
   - 13개 근육 key × 좌표 + 크기 (또는 path shape)
   - CSV 또는 JSON으로 좌표표 작성

3. 코드: `BodyHeatmapPainter` 리팩토링
   - PNG 로드 + 렌더링
   - 근육별 overlay 루프
   - 기존 CustomPainter 대체

**예상 작업량**: 
- 디자이너: 1~2일 (asset 준비 + 좌표 정의)
- 구현자: 2~3시간 (코드 작성)

### 5.2 중기 (2주 이후)

**선택: SVG Asset으로 마이그레이션 (선택사항)**

**이유**:
- 반응형 확대 필요 시
- 근육 경계선 상세 표현 필요 시
- 3D mesh 생성 참고 자료로 SVG path 활용 시

**마이그레이션 난이도**: 낮음 (기존 overlay 로직 재사용 가능)

---

## 6. CustomPainter 현재 구현 처리 방안

### 6.1 현재 파일의 활용 여부

| 파일 | 처리 방향 |
|------|---------|
| `FrontBodyHeatmapPainter` | 삭제 또는 아카이브 (PNG 기반으로 대체) |
| `BackBodyHeatmapPainter` | 삭제 또는 아카이브 (PNG 기반으로 대체) |
| `BodyHeatmapRegion` | **유지** (데이터 모델로 계속 사용) |
| `BodyHeatmapRegionAdapter` | **유지** (데이터 변환 로직 계속 사용) |
| `BodyHeatmapView` | **유지** (전면/후면 전환 로직 재사용) |
| `HeatmapTab` | **유지** (UI 구조 변경 없음) |

### 6.2 코드 재사용 전략

**기존 데이터 처리 로직**:
```dart
// 계속 사용
final regions = buildBodyHeatmapRegionsFromData(widget.data);
final selectedSide = _frontSelected 
    ? BodyHeatmapViewSide.front 
    : BodyHeatmapViewSide.back;
```

**기존 CustomPainter 로직**:
```dart
// 교체 대상
// FrontBodyHeatmapPainter._heatmapColorForPercent() 함수는
// 새 PngBodyHeatmapPainter에서 재사용 가능
```

---

## 7. 사람이 준비해야 할 것 (체크리스트)

### 7.1 PNG Asset 기반 선택 시

**필수**:
- [ ] 디자이너: 전면 신체 실루엣 PNG (390×390px)
- [ ] 디자이너: 후면 신체 실루엣 PNG (390×390px)
- [ ] 디자이너 또는 구현자: 13개 근육별 overlay 영역 좌표 정의표
  ```
  left_chest: {x: ..., y: ..., width: ..., height: ...}
  right_chest: {...}
  ... (11개 추가)
  ```

**선택**:
- [ ] PNG @2x 고해상도 버전 (옵션)
- [ ] 근육 경계선 강조 (초기 버전에서는 생략 가능)

**작업량 추정**:
- 디자이너: 4~6시간
- 구현자: 2~3시간

### 7.2 SVG Asset 기반 선택 시

**필수**:
- [ ] 디자이너: 전면 SVG (각 근육을 path id로 정의)
- [ ] 디자이너: 후면 SVG (각 근육을 path id로 정의)

**예시**:
```svg
<svg>
  <g id="front-body">
    <path id="left_chest" d="M ... Z" />
    <path id="right_chest" d="M ... Z" />
    ... (11개 추가)
  </g>
</svg>
```

**작업량 추정**:
- 디자이너: 6~8시간
- 구현자: 2~3시간

---

## 8. AI 코딩 도구 (Codex/Claude)가 구현할 수 있는 것

### 8.1 PNG 기반 구현

**완전 자동화 가능**:
- ✅ PNG 로드 (`ui.Image`, `rootBundle`)
- ✅ Canvas 렌더링 로직
- ✅ 근육별 overlay 루프
- ✅ 색상 매핑 로직
- ✅ 전면/후면 분기 처리

**준자동**:
- ⚠️ 좌표표 검증 및 최적화 (좌표 제공 필요)

**불가능**:
- ❌ 디자인 (PNG 그리기 또는 asset 준비)
- ❌ 좌표 측정 (asset 제공 필요)

### 8.2 SVG 기반 구현

**완전 자동화 가능**:
- ✅ SVG 로드 (`flutter_svg`)
- ✅ SVG document 분석
- ✅ path id 기준 색상 변경
- ✅ 렌더링 로직

**준자동**:
- ⚠️ SVG 구조 검증

**불가능**:
- ❌ SVG 그리기 (디자인 도구 필요)

### 8.3 구현 예상 코드량

**PNG 기반 PainterClass**: ~120 lines
```dart
class PngBodyHeatmapPainter extends CustomPainter {
  // PNG 로드
  // 렌더링 로직
  // overlay 루프
  // 색상 매핑
}
```

**SVG 기반 구현**: ~100 lines (flutter_svg 활용)

---

## 9. 다음 지라 작업 제안

### 9.1 22번 작업: 2D 히트맵 시각화 개선 (Asset 준비 단계)

**작업명**: `[APP][Stats] 2D 근육 히트맵 신체 실루엣 asset 준비`

**작업 내용**:
- 디자이너: 전면/후면 신체 실루엣 PNG 또는 SVG 준비
- 프로덕트: 13개 근육 영역 좌표/shape 정의

**완료 기준**:
- PNG 2개 준비 완료
- 근육별 overlay 영역 좌표표 작성 완료
- assets/ 디렉터리에 배치 완료

**담당**: 디자이너

### 9.2 23번 작업: 2D 히트맵 PNG 기반 구현

**작업명**: `[APP][Stats] 2D 근육 히트맵 PNG asset 기반 렌더링 구현`

**작업 내용**:
- `FrontBodyHeatmapPainter` 및 `BackBodyHeatmapPainter` PNG 기반으로 리팩토링
- 근육별 overlay 영역 적용
- HeatmapTab 통합 (기존 코드 유지)

**완료 기준**:
- `flutter analyze` 통과
- 전면/후면 전환 동작 확인
- 색상 레이블 표시 확인
- 근육 레이블 표시 확인

**담당**: 프론트엔드 구현자

### 9.3 24번 작업: 2D 히트맵 legend & trunk badge (선택)

**작업명**: `[APP][Stats] 히트맵 범례 및 자세 안정성 badge 추가`

**작업 내용**:
- Legend 색상 개선 (기존 유지, 시각적 다듬기만)
- Trunk posture stability badge 추가
- 반응형 레이아웃 조정

---

## 10. 결론 및 최종 권고

### 10.1 현재 구현 평가

| 항목 | 판정 | 근거 |
|------|------|------|
| **기능 완성도** | ✅ 완전 | 21번 작업으로 기능 완성 |
| **시각 퀄리티** | ❌ 부족 | CustomPainter 도형 기반은 부자연스러움 |
| **사용성** | ⚠️ 보통 | 근육 부위 인식은 가능하나 professional 부족 |
| **확장성** | ❌ 낮음 | CustomPainter 좌표 하드코딩 방식 |

### 10.2 현재 CustomPainter 고도화 권고

**결론: 현재 CustomPainter를 계속 개선하는 것은 비추천**

**근거**:
1. 개발 투자 대비 시각 개선 폭이 제한적
2. Bezier curve 기반 path 작성은 복잡도 지수 증가
3. 결국 asset 기반으로 마이그레이션할 가능성 높음
4. 초기 구현 (형태 개선) 후에도 운영 복잡도 증가

**대신 권장**:
- 현재 CustomPainter는 **프로토타입**으로 보고 **아카이브** 처리
- Asset 기반 방식으로 **새로 구현**
- 기존 데이터 모델/로직은 **재사용**

### 10.3 MVP 추천안 (명확한 판단)

**✅ PNG Asset 기반 방식 채택**

**이유**:
- 시각 퀄리티 즉각 개선 ⭐⭐⭐⭐⭐
- 구현 난이도 낮음 ⭐⭐
- MVP 적합성 최고 ⭐⭐⭐⭐⭐
- 발표 효과 우수 ⭐⭐⭐⭐⭐
- 다음 3D 작업 호환 ⭐⭐⭐

**구현 로드맵**:
```
22번: Asset 준비 (디자이너 1~2일)
  ↓
23번: PNG 기반 구현 (구현자 2~3시간)
  ↓
24번: Legend & Trunk 추가 (구현자 1~2시간)
  ↓
시연/발표 (완성된 2D 히트맵)
```

**예상 전체 소요 시간**: 1.5 ~ 2주 (asset 준비 포함)

### 10.4 발표/시연용 권고

**현재 상태로는 부족**:
- 기하학적 도형으로 된 신체는 "근육 히트맵"이라고 설명하기 어려움
- 참석자들이 실제 근육 활성도 시각화인지 의심할 수 있음

**PNG 기반 개선 후**:
- Realistic 신체 실루엣 + 색상 overlay = "근육 히트맵" 즉시 인식
- Professional 느낌으로 상승
- 3D 예정 설명과 자연스럽게 연결

### 10.5 지금 바로 해야 할 일

| 우선순위 | 항목 | 담당 | 기한 |
|---------|------|------|------|
| **1순위** | 디자이너에 PNG/SVG asset 요청 | PM/PO | 즉시 |
| **2순위** | 근육 영역 좌표표 작성 | 디자인/구현 | Asset 준비 후 |
| **3순위** | 23번 작업 준비 (코드 스케치) | 구현자 | asset 준비 전 |

---

## 11. 프로젝트 구조 변경 없음 확인

**본 문서 작성 시 수행된 작업**:
- ✅ 기존 코드 수정 없음
- ✅ 파일 이동 없음
- ✅ pubspec.yaml 수정 없음
- ✅ 패키지 설치 없음
- ✅ HeatmapTab 구조 유지
- ✅ 현재 데이터 모델 유지
- ✅ 문서 작성만 수행

**다음 단계에서만 코드 수정 예정** (22~23번 작업):
- 디자이너: PNG/SVG asset 생성 (코드 외)
- 구현자: `PngBodyHeatmapPainter` 구현 (신규)
- 구현자: `BodyHeatmapView` 리팩토링 (기존 대체)

---

## 12. 최종 체크리스트

**현재 21번 작업 이후**:
- [x] 기능 완성도 100% (데이터 연결, 전면/후면 전환)
- [x] 시각 퀄리티 부족 확인 (도형 기반 문제점 파악)
- [x] CustomPainter 고도화 비추천 결정
- [x] PNG Asset 기반 방식 채택 결정
- [x] 22~24번 작업 제안 완료
- [x] 사람이 준비할 것 리스트 작성 완료
- [x] AI 구현 가능 범위 정의 완료

**다음 단계 (22번)**:
- [ ] 디자이너: PNG asset 준비 시작
- [ ] PM: 근육 좌표표 정의 작업 계획
- [ ] 구현자: 23번 코드 스케치 준비

---

**최종 결론**:

> 현재 CustomPainter 방식은 MVP 단계 기능 완성에는 충분하지만, **시각 퀄리티가 실제 근육 히트맵으로 인식되기에는 부족**하다. **PNG/SVG asset 기반으로 전환하여 realistic 신체 실루엣 + 색상 overlay 방식으로 개선**하는 것이 **MVP 시연, 발표 효과, 장기 확장성 모든 측면에서 최적의 선택**이다. **당장 코드 작업을 계속하기보다 asset 전략을 확정하고 디자이너 작업을 시작**하는 것이 올바른 순서다.
