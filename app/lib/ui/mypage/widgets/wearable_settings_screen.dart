import 'package:flutter/material.dart';

import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';

class WearableSettingsScreen extends StatelessWidget {
  const WearableSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Wearable Settings',
      subtitle: 'Device connection overview',
      showBackButton: true,
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Connection status', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.sm),
          const _DeviceConnectionCard(
            icon: Icons.memory_rounded,
            title: 'Raspberry Pi',
            description: 'WebSocket server for workout events',
            badge: StatusBadge(label: 'Standby', variant: StatusVariant.info),
          ),
          const SizedBox(height: AppSpacing.sm),
          const _DeviceConnectionCard(
            icon: Icons.sensors_rounded,
            title: 'ESP32 sensors',
            description: 'EMG and IMU sensor bridge',
            badge: StatusBadge(
              label: 'Pending',
              variant: StatusVariant.neutral,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const _DeviceConnectionCard(
            icon: Icons.visibility_rounded,
            title: 'Smart glass',
            description: 'Workout guide display device',
            badge: StatusBadge(
              label: 'Pending',
              variant: StatusVariant.neutral,
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          Text('Pi WebSocket', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.sm),
          ImoCard(
            paddingSize: ImoCardPadding.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Default endpoint', style: AppTextStyles.label),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'ws://192.168.0.100:8765',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Actual connect, retry, and status sync will be handled by the Pi WebSocket service branch.',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          ImoButton(
            label: 'Reconnect devices',
            variant: ImoButtonVariant.outline,
            icon: Icons.refresh_rounded,
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

class _DeviceConnectionCard extends StatelessWidget {
  const _DeviceConnectionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.badge,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget badge;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      paddingSize: ImoCardPadding.lg,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.cardSubtle,
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            ),
            child: Icon(icon, color: AppColors.primaryStrong),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.label),
                const SizedBox(height: AppSpacing.xxs),
                Text(description, style: AppTextStyles.caption),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          badge,
        ],
      ),
    );
  }
}
