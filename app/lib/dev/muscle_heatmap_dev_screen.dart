import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MuscleHeatmapDevScreen extends StatelessWidget {
  const MuscleHeatmapDevScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Muscle Heatmap Dev')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                '[PoC] ColorMapper 동작 확인\n'
                '흉근(left_chest)=빨강, 복근(left_rectus_abdominis)=파랑',
                textAlign: TextAlign.center,
              ),
            ),
            SvgPicture.asset(
              'assets/svg/male_front_body.svg',
              width: 195,
              height: 390,
              colorMapper: const _DebugColorMapper(),
            ),
            const Divider(),
            const Text('Male Front (neutral)'),
            SvgPicture.asset(
              'assets/svg/male_front_body.svg',
              width: 195,
              height: 390,
            ),
            const Text('Male Back (neutral)'),
            SvgPicture.asset(
              'assets/svg/male_back_body.svg',
              width: 195,
              height: 390,
            ),
            const Text('Female Front (neutral)'),
            SvgPicture.asset(
              'assets/svg/female_front_body.svg',
              width: 195,
              height: 390,
            ),
            const Text('Female Back (neutral)'),
            SvgPicture.asset(
              'assets/svg/female_back_body.svg',
              width: 195,
              height: 390,
            ),
          ],
        ),
      ),
    );
  }
}

class _DebugColorMapper extends ColorMapper {
  const _DebugColorMapper();

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    debugPrint('ColorMapper → id=$id  element=$elementName  attr=$attributeName');

    // 단일 path 케이스
    if (id == 'left_chest') return Colors.red;

    // <g id="..."> 그룹 내부 sub-path 케이스
    if (id == 'left_rectus_abdominis') return Colors.blue;

    return color;
  }
}
