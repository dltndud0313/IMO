import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 보상동작 감지 시 화면 위에 띄우는 경고 오버레이.
class CompensationOverlay extends StatelessWidget {
  const CompensationOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.accent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '보상동작 감지!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
