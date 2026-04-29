import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';

class SensorGuideScreen extends StatefulWidget {
  const SensorGuideScreen({
    super.key,
    this.exerciseId = 'pushup',
  });

  final String exerciseId;

  @override
  State<SensorGuideScreen> createState() => _SensorGuideScreenState();
}

class _SensorGuideScreenState extends State<SensorGuideScreen> {
  final Set<String> _checkedSensorIds = {};

  _SensorConfig get _config =>
      _sensorConfigs[widget.exerciseId] ?? _sensorConfigs['pushup']!;

  bool get _allChecked =>
      _config.sensors.every((sensor) => _checkedSensorIds.contains(sensor.id));

  void _toggleSensor(String id) {
    setState(() {
      if (_checkedSensorIds.contains(id)) {
        _checkedSensorIds.remove(id);
      } else {
        _checkedSensorIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _config.title,
      subtitle: 'Sensor placement',
      showBackButton: true,
      scrollable: true,
      bottom: ImoButton(
        label: _allChecked ? 'Start calibration' : 'Check all sensors',
        disabled: !_allChecked,
        rightIcon: const Icon(Icons.arrow_forward_rounded),
        onPressed: _allChecked
            ? () => context.go('/workout-calibration?exercise=${widget.exerciseId}')
            : null,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SensorMapCard(config: _config),
          const SizedBox(height: AppSpacing.sectionGap),
          Text('Placement checklist', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.sm),
          for (final sensor in _config.sensors) ...[
            _SensorCheckTile(
              sensor: sensor,
              checked: _checkedSensorIds.contains(sensor.id),
              onTap: () => _toggleSensor(sensor.id),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.md),
          const _SensorNoticeCard(),
        ],
      ),
    );
  }
}

class _SensorMapCard extends StatelessWidget {
  const _SensorMapCard({required this.config});

  final _SensorConfig config;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      variant: ImoCardVariant.hero,
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.sensors_rounded,
                color: AppColors.primaryStrong,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text('Attachment map', style: AppTextStyles.label),
              const Spacer(),
              StatusBadge(
                label: '${config.sensors.length} sensors',
                variant: StatusVariant.info,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            height: 260,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFEAF5FF), AppColors.background],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(color: AppColors.border),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    Icons.accessibility_new_rounded,
                    size: 132,
                    color: AppColors.primary.withValues(alpha: 0.12),
                  ),
                ),
                for (var index = 0; index < config.sensors.length; index++)
                  _SensorMapMarker(
                    index: index + 1,
                    sensor: config.sensors[index],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SensorMapMarker extends StatelessWidget {
  const _SensorMapMarker({
    required this.index,
    required this.sensor,
  });

  final int index;
  final _SensorInfo sensor;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: sensor.top,
      left: sensor.left,
      right: sensor.right,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: 0,
                  spreadRadius: 6,
                ),
              ],
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                color: AppColors.card,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              sensor.position,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SensorCheckTile extends StatelessWidget {
  const _SensorCheckTile({
    required this.sensor,
    required this.checked,
    required this.onTap,
  });

  final _SensorInfo sensor;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      interactive: true,
      onTap: onTap,
      variant: checked ? ImoCardVariant.subtle : ImoCardVariant.defaultCard,
      paddingSize: ImoCardPadding.md,
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: checked ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(AppSpacing.xs),
              border: Border.all(
                color: checked ? AppColors.primary : AppColors.border,
                width: 2,
              ),
            ),
            child: checked
                ? const Icon(
                    Icons.check_rounded,
                    color: AppColors.card,
                    size: 18,
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sensor.position, style: AppTextStyles.label),
                const SizedBox(height: AppSpacing.xxs),
                Text(sensor.label, style: AppTextStyles.caption),
              ],
            ),
          ),
          StatusBadge(
            label: checked ? 'Checked' : 'Pending',
            variant: checked ? StatusVariant.success : StatusVariant.neutral,
          ),
        ],
      ),
    );
  }
}

class _SensorNoticeCard extends StatelessWidget {
  const _SensorNoticeCard();

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      variant: ImoCardVariant.outlined,
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: AppColors.primaryStrong,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text('Before calibration', style: AppTextStyles.label),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const _NoticeLine('Attach sensors firmly to clean, dry skin.'),
          const SizedBox(height: AppSpacing.xs),
          const _NoticeLine('Keep the sensor order consistent with the map.'),
          const SizedBox(height: AppSpacing.xs),
          const _NoticeLine('Check that the IMU is stable before moving on.'),
        ],
      ),
    );
  }
}

class _NoticeLine extends StatelessWidget {
  const _NoticeLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Icon(Icons.circle, size: 6, color: AppColors.primaryStrong),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: Text(text, style: AppTextStyles.bodySmall)),
      ],
    );
  }
}

class _SensorConfig {
  const _SensorConfig({
    required this.title,
    required this.sensors,
  });

  final String title;
  final List<_SensorInfo> sensors;
}

class _SensorInfo {
  const _SensorInfo({
    required this.id,
    required this.label,
    required this.position,
    required this.top,
    this.left,
    this.right,
  });

  final String id;
  final String label;
  final String position;
  final double top;
  final double? left;
  final double? right;
}

const _sensorConfigs = {
  'pushup': _SensorConfig(
    title: 'Push-up',
    sensors: [
      _SensorInfo(
        id: 'emg_1',
        label: 'EMG 1',
        position: 'Chest',
        top: 72,
        left: 92,
      ),
      _SensorInfo(
        id: 'emg_2',
        label: 'EMG 2',
        position: 'Shoulder',
        top: 96,
        right: 54,
      ),
      _SensorInfo(
        id: 'emg_3',
        label: 'EMG 3',
        position: 'Triceps',
        top: 56,
        right: 86,
      ),
      _SensorInfo(
        id: 'imu_1',
        label: 'IMU',
        position: 'Upper back',
        top: 132,
        left: 112,
      ),
    ],
  ),
  'lateral_raise': _SensorConfig(
    title: 'Lateral raise',
    sensors: [
      _SensorInfo(
        id: 'emg_1',
        label: 'EMG 1',
        position: 'Side deltoid',
        top: 64,
        right: 56,
      ),
      _SensorInfo(
        id: 'emg_2',
        label: 'EMG 2',
        position: 'Upper trapezius',
        top: 44,
        left: 108,
      ),
      _SensorInfo(
        id: 'emg_3',
        label: 'EMG 3',
        position: 'Rear shoulder',
        top: 72,
        left: 64,
      ),
      _SensorInfo(
        id: 'imu_1',
        label: 'IMU',
        position: 'Wrist',
        top: 148,
        right: 42,
      ),
    ],
  ),
  'bicep_curl': _SensorConfig(
    title: 'Bicep curl',
    sensors: [
      _SensorInfo(
        id: 'emg_1',
        label: 'EMG 1',
        position: 'Biceps',
        top: 104,
        left: 54,
      ),
      _SensorInfo(
        id: 'emg_2',
        label: 'EMG 2',
        position: 'Forearm',
        top: 148,
        left: 46,
      ),
      _SensorInfo(
        id: 'emg_3',
        label: 'EMG 3',
        position: 'Shoulder',
        top: 80,
        right: 58,
      ),
      _SensorInfo(
        id: 'imu_1',
        label: 'IMU',
        position: 'Wrist',
        top: 150,
        right: 46,
      ),
    ],
  ),
};
