import 'package:flutter/material.dart';

import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';

class WearableSettingsScreen extends StatelessWidget {
  const WearableSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '웨어러블 설정',
      subtitle: '기기 연결 상태',
      showBackButton: true,
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('연결 상태', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.sm),
          const _DeviceConnectionCard(
            icon: Icons.memory_rounded,
            title: 'Raspberry Pi',
            description: '운동 이벤트를 주고받는 WebSocket 서버',
            badge: StatusBadge(label: '대기 중', variant: StatusVariant.info),
          ),
          const SizedBox(height: AppSpacing.sm),
          const _DeviceConnectionCard(
            icon: Icons.sensors_rounded,
            title: 'ESP32 센서',
            description: 'EMG 및 IMU 센서 브리지',
            badge: StatusBadge(
              label: '대기',
              variant: StatusVariant.neutral,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const _DeviceConnectionCard(
            icon: Icons.visibility_rounded,
            title: '스마트 글래스',
            description: '운동 안내를 표시하는 기기',
            badge: StatusBadge(
              label: '대기',
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
                Text('기본 엔드포인트', style: AppTextStyles.label),
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
                  '실제 연결, 재시도, 상태 동기화는 Pi WebSocket 서비스 작업에서 연결합니다.',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          ImoButton(
            label: '기기 다시 연결',
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