import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../stats/widgets/svg_body_heatmap_view.dart' show BodyGender;
import 'exercise_target_regions.dart' show BodyCropConfig;

/// [CroppedBodySvg] 의 overlay 빌더 시그니처.
///
/// SVG 가 차지하는 실제 픽셀 너비/높이를 받아서, 그 좌표계 안에 위젯을 배치할
/// 수 있게 함. 비율 좌표 (0~1) 의 마커를 `dx * svgWidth`, `dy * svgHeight`
/// 로 변환해 `Positioned` 로 배치하는 패턴 권장.
typedef BodyOverlayBuilder = Widget Function(
  BuildContext context,
  double svgWidth,
  double svgHeight,
);

/// SVG 바디 자산을 [crop] 설정대로 잘라서 보여주는 공통 위젯.
///
/// 자세 가이드 (타겟 근육 색 강조) 와 센서 부착 안내 (위에 마커 오버레이) 가
/// 같은 SVG 자산 + 같은 crop 동작을 공유하도록 추출.
///
/// - 색 강조 필요 시 [colorMapper] 주입
/// - SVG 와 같은 좌표계의 오버레이가 필요하면 [overlayBuilder] 주입.
///   overlay 도 SVG 와 같이 crop + zoom 됨 → 마커가 신체 부위 위에 정확히 떨어짐.
class CroppedBodySvg extends StatelessWidget {
  const CroppedBodySvg({
    super.key,
    required this.assetPath,
    required this.crop,
    this.colorMapper,
    this.overlayBuilder,
  });

  final String assetPath;
  final BodyCropConfig crop;
  final ColorMapper? colorMapper;
  final BodyOverlayBuilder? overlayBuilder;

  // 원본 SVG viewBox 비율 (724 / 1450).
  static const _svgAspectRatio = 724.0 / 1450.0;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 줌 배율 만큼 SVG 자체 크기를 키우고, OverflowBox 로 부모를 넘어가게.
          // 부모는 ClipRect 라 잘라서 보여줌. alignment 로 어떤 부분을 보여줄지 결정.
          final svgHeight = constraints.maxHeight * crop.zoom;
          final svgWidth = svgHeight * _svgAspectRatio;
          return OverflowBox(
            alignment: crop.alignment,
            minWidth: svgWidth,
            maxWidth: svgWidth,
            minHeight: svgHeight,
            maxHeight: svgHeight,
            child: Stack(
              children: [
                Positioned.fill(
                  child: SvgPicture.asset(
                    assetPath,
                    colorMapper: colorMapper,
                    fit: BoxFit.contain,
                  ),
                ),
                if (overlayBuilder != null)
                  Positioned.fill(
                    child: overlayBuilder!(context, svgWidth, svgHeight),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 성별 / 전후면에 따른 SVG 자산 경로.
String bodySvgAssetPath(BodyGender gender, {required bool isBack}) {
  final g = gender == BodyGender.female ? 'female' : 'male';
  final s = isBack ? 'back' : 'front';
  return 'assets/svg/${g}_${s}_body.svg';
}
