# Muscle Heatmap SVG — Flutter 통합 가이드 v3

## 변경 사항 (v2 → v3)
1. **Deltoid 분리**: front view에서 anterior + lateral 분리 (자동 path bisection)
2. **`lower_back`로 이름 변경**: 이전 `lower_trapezius` → 실제 해부학적 위치(요추)와 일치
3. **뒷면 forearm 추가**: back view에도 left/right_forearm 포함
4. **머리/머리카락/손/발/관절 포함**: silhouette에 자연스럽게 통합 (이전엔 잘림)
5. **여성형 추가**: female_front_body.svg, female_back_body.svg
6. **Multi sub-path 그룹 처리**: abs, oblique, calves 같이 여러 sub-path를 가진 근육은 `<g id="...">` 그룹으로 묶음 (좌표 누적 버그 방지)

## 파일 구성
- `male_front_body.svg` — 남성 전면
- `male_back_body.svg` — 남성 후면
- `female_front_body.svg` — 여성 전면
- `female_back_body.svg` — 여성 후면
- `LICENSE_react-native-body-highlighter.txt` — 원본 MIT 라이선스 (필수 동봉)

## 라이선스
SVG path 데이터는 **MIT License의 [react-native-body-highlighter](https://github.com/HichamELBSI/react-native-body-highlighter) (© 2022 ELABBASSI Hicham)** 에서 가져왔습니다. 앱 내 "오픈소스 라이선스" 화면에 라이선스 전문 포함 필수.

## 디자인 스펙
| 항목 | 값 |
|---|---|
| 신체 fill | `#E5E7EB` |
| 근육 fill (neutral 기본) | `#BFC3CB` |
| 머리카락 fill | `#9CA3AF` |
| 스트로크 | `#94A3B0` |
| 표시 비율 | 1:2 (390x780 권장) |

## Path ID 목록 (남녀 동일)

### 전면 - 18개
**MVP**
- `left_chest`, `right_chest`
- `left_biceps`, `right_biceps`
- `left_forearm`, `right_forearm`
- `left_lateral_deltoid`, `right_lateral_deltoid`

**확장용**
- `left_anterior_deltoid`, `right_anterior_deltoid` ✨ *별도 path로 분리됨*
- `left_rectus_abdominis`, `right_rectus_abdominis`
- `left_oblique`, `right_oblique`
- `left_quadriceps`, `right_quadriceps`
- `left_tibialis_anterior`, `right_tibialis_anterior`

### 후면 - 18개
**MVP**
- `left_triceps`, `right_triceps`
- `left_upper_trapezius`, `right_upper_trapezius`

**확장용**
- `left_rear_deltoid`, `right_rear_deltoid`
- `left_latissimus_dorsi`, `right_latissimus_dorsi`
- `left_lower_back`, `right_lower_back` ✨ *이름 변경 (이전 lower_trapezius)*
- `left_forearm`, `right_forearm` ✨ *추가됨*
- `left_glute`, `right_glute`
- `left_hamstrings`, `right_hamstrings`
- `left_calves`, `right_calves`

## ⚠️ 중요: Path/Group ID 매칭

SVG 안에서 근육은 두 가지 형태로 정의되어 있어요:
- **단일 path**: `<path id="left_chest" fill="#BFC3CB" d="..."/>`
- **다중 sub-path 그룹**: `<g id="left_rectus_abdominis" fill="#BFC3CB">` ... `</g>`

Flutter에서 색상을 교체할 때 **두 형태 모두 매칭**해야 해요.

## Flutter 통합 코드

```yaml
# pubspec.yaml
dependencies:
  flutter_svg: ^2.0.0

flutter:
  assets:
    - assets/svg/male_front_body.svg
    - assets/svg/male_back_body.svg
    - assets/svg/female_front_body.svg
    - assets/svg/female_back_body.svg
```

```dart
// muscle_heatmap.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum BodyView { front, back }
enum BodyGender { male, female }

class MuscleHeatmap extends StatelessWidget {
  final BodyView view;
  final BodyGender gender;
  final Map<String, double> intensities; // muscle_id -> 0.0~1.0
  final double width;

  const MuscleHeatmap({
    super.key,
    required this.view,
    required this.gender,
    required this.intensities,
    this.width = 195,
  });

  String get _assetPath {
    final g = gender == BodyGender.male ? 'male' : 'female';
    final v = view == BodyView.front ? 'front' : 'back';
    return 'assets/svg/${g}_${v}_body.svg';
  }

  // Blue (low) → Yellow → Red (high) gradient
  Color _intensityToColor(double t) {
    t = t.clamp(0.0, 1.0);
    if (t < 0.5) {
      return Color.lerp(
        const Color(0xFF60A5FA), // blue
        const Color(0xFFFAD23C), // yellow
        t / 0.5,
      )!;
    }
    return Color.lerp(
      const Color(0xFFFAD23C),
      const Color(0xFFEF4444), // red
      (t - 0.5) / 0.5,
    )!;
  }

  String _colorToHex(Color c) =>
      '#${c.red.toRadixString(16).padLeft(2, '0')}'
      '${c.green.toRadixString(16).padLeft(2, '0')}'
      '${c.blue.toRadixString(16).padLeft(2, '0')}';

  Future<String> _buildSvg() async {
    String svg = await rootBundle.loadString(_assetPath);
    intensities.forEach((id, intensity) {
      final color = _colorToHex(_intensityToColor(intensity));
      // IMPORTANT: match both <path id="..." fill="..."> and <g id="..." fill="...">
      final pathPattern = RegExp('(<path id="$id" fill=")[^"]*(")');
      final groupPattern = RegExp('(<g id="$id" fill=")[^"]*(")');
      svg = svg
          .replaceAllMapped(pathPattern, (m) => '${m[1]}$color${m[2]}')
          .replaceAllMapped(groupPattern, (m) => '${m[1]}$color${m[2]}');
    });
    return svg;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _buildSvg(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(width: width, height: width * 2);
        }
        return SvgPicture.string(
          snapshot.data!,
          width: width,
          height: width * 2,
        );
      },
    );
  }
}
```

## 사용 예시

```dart
// 통계 카드에 전면 + 후면 나란히
Row(
  children: [
    MuscleHeatmap(
      view: BodyView.front,
      gender: user.gender == 'F' ? BodyGender.female : BodyGender.male,
      intensities: {
        'left_chest': 0.95,
        'right_chest': 0.88,
        'left_anterior_deltoid': 0.75, // 푸시업 강조
        'right_anterior_deltoid': 0.70,
        'left_biceps': 0.40,
        'right_biceps': 0.40,
      },
    ),
    MuscleHeatmap(
      view: BodyView.back,
      gender: user.gender == 'F' ? BodyGender.female : BodyGender.male,
      intensities: {
        'left_triceps': 0.80,
        'right_triceps': 0.75,
      },
    ),
  ],
)
```

## MVP 운동별 추천 매핑

| 운동 | Front 활성 근육 | Back 활성 근육 |
|---|---|---|
| **푸시업** | chest, anterior_deltoid, biceps(보조) | triceps |
| **사이드 레터럴 레이즈 (싸레레)** | lateral_deltoid | upper_trapezius |
| **이두컬** | biceps, anterior_deltoid(보조), forearm | — |

## 향후 확장 시 참고

### Trunk 자세 안정성 indicator
근육이 아니므로 별도 위젯/오버레이로 처리. 척추 라인을 따라 dot/badge 표시 권장.

### 다크모드
SVG 빌드 시 base body color (`#E5E7EB`)와 neutral muscle (`#BFC3CB`)도 함께 치환. `_buildSvg`에 두 줄 추가하면 됨.

### 좌/우 비대칭 강조
좌우 근육에 다른 intensity 주면 자동으로 비대칭 시각화. 예: 푸시업 시 한쪽 가슴만 진한 빨강.

## 검증 결과
- ✅ 남성 전면: 18개 path/group 정확한 위치 (audit 통과)
- ✅ 남성 후면: 18개 path/group 정확한 위치
- ✅ 여성 전면: 18개 path/group 정확한 위치
- ✅ 여성 후면: 18개 path/group 정확한 위치
- ✅ 머리/머리카락/손/발/관절 모두 silhouette에 포함됨
- ✅ Anterior/Lateral deltoid 분리 동작 검증됨
- ✅ Heatmap 미적용 시 모든 근육 neutral gray 유지
- ✅ MIT 라이선스 (상업적 사용 가능)
