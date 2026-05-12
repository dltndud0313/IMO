import 'package:flutter/material.dart';

import '../../core/themes/design_tokens.dart';

class StatsEmptyState extends StatelessWidget {
  const StatsEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.subMessage,
  });

  final IconData icon;
  final String message;
  final String? subMessage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: AppColors.textTertiary),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          if (subMessage != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subMessage!,
              style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
