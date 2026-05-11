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
