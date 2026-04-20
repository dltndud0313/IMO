import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 근피로 감지 시 상단에 표시되는 배너.
class FatigueBanner extends StatelessWidget {
  const FatigueBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warning),
      ),
      child: const Row(
        children: [
          Icon(Icons.battery_alert, color: AppTheme.warning),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '근피로가 감지되었어요. 잠시 휴식하세요.',
              style: TextStyle(
                color: AppTheme.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
