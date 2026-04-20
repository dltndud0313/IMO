import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'confetti_overlay.dart';

/// 주간 목표 달성 시 축하 다이얼로그.
class GoalAchievementDialog extends StatelessWidget {
  final String message;
  const GoalAchievementDialog({
    super.key,
    this.message = '이번 주 목표를 모두 달성했어요!',
  });

  static Future<void> show(BuildContext context, {String? message}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => GoalAchievementDialog(
        message: message ?? '이번 주 목표를 모두 달성했어요!',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: ConfettiOverlay()),
        Center(
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      size: 48,
                      color: AppTheme.success,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '목표 달성!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('확인'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
