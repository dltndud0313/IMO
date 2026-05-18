import 'package:flutter/material.dart';

import '../../core/widgets/status_badge.dart';
import '../model/smartglass_display_models.dart';

class SmartglassConnectionChip extends StatelessWidget {
  const SmartglassConnectionChip({super.key, required this.connectionState});

  final SmartglassConnectionState connectionState;

  @override
  Widget build(BuildContext context) {
    switch (connectionState) {
      case SmartglassConnectionState.connected:
        return const StatusBadge(
          label: '연결 안정',
          variant: StatusVariant.success,
          size: StatusBadgeSize.md,
        );
      case SmartglassConnectionState.connecting:
        return const StatusBadge(
          label: '연결 중',
          variant: StatusVariant.info,
          size: StatusBadgeSize.md,
        );
      case SmartglassConnectionState.disconnected:
        return const StatusBadge(
          label: '연결 끊김',
          variant: StatusVariant.error,
          size: StatusBadgeSize.md,
        );
    }
  }
}
