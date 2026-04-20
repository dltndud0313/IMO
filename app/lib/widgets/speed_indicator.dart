import 'package:flutter/material.dart';

import '../models/realtime_state.dart';
import '../theme/app_theme.dart';

class SpeedIndicator extends StatelessWidget {
  final RepSpeed speed;
  const SpeedIndicator({super.key, required this.speed});

  @override
  Widget build(BuildContext context) {
    late Color color;
    late String label;
    late IconData icon;
    switch (speed) {
      case RepSpeed.fast:
        color = AppTheme.accent;
        label = '빠름';
        icon = Icons.fast_forward;
        break;
      case RepSpeed.normal:
        color = AppTheme.success;
        label = '정상';
        icon = Icons.check_circle;
        break;
      case RepSpeed.slow:
        color = AppTheme.warning;
        label = '느림';
        icon = Icons.slow_motion_video;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
