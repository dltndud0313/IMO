import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../stats/widgets/svg_body_heatmap_view.dart' show BodyGender;
import 'exercise_target_regions.dart' show BodyCropConfig;

/// SVG 바디 자산을 [crop] 설정대로 잘라서 보여주는 공통 위젯.
///
/// 자세 가이드 (타겟 근육 색 강조) 와 센서 부착 안내 (위에 마커 오버레이) 가
/// 같은 SVG 자산 + 같은 crop 동작을 공유하도록 추출.
///
/// 색 강조가 필요하면 [colorMapper] 에 ColorMapper 인스턴스 주입.
class CroppedBodySvg extends StatelessWidget {
  const CroppedBodySvg({
    super.key,
    required this.assetPath,
    required this.crop,
    this.colorMapper,
  });

  final String assetPath;
  final BodyCropConfig crop;
  final ColorMapper? colorMapper;

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
            child: SvgPicture.asset(
              assetPath,
              colorMapper: colorMapper,
              fit: BoxFit.contain,
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
