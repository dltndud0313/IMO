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
      subtitle: '센서 부착',
      showBackButton: true,
      scrollable: true,
      bottom: ImoButton(
        label: _allChecked ? '캘리브레이션 시작' : '센서 확인 필요',
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
          Text('부착 체크리스트', style: AppTextStyles.sectionTitle),
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
              Text('센서 부착 위치', style: AppTextStyles.label),
              const Spacer(),
              StatusBadge(
                label: '센서 ${config.sensors.length}개',
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
            label: checked ? '확인됨' : '대기',
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
              Text('캘리브레이션 전 확인', style: AppTextStyles.label),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const _NoticeLine('깨끗하고 건조한 피부에 센서를 단단히 부착합니다.'),
          const SizedBox(height: AppSpacing.xs),
          const _NoticeLine('센서 순서가 부착 위치 안내와 일치하는지 확인합니다.'),
          const SizedBox(height: AppSpacing.xs),
          const _NoticeLine('다음 단계로 이동하기 전에 IMU가 안정적인지 확인합니다.'),
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
    title: '푸시업',
    sensors: [
      _SensorInfo(
        id: 'emg_1',
        label: 'EMG 1',
        position: '가슴',
        top: 72,
        left: 92,
      ),
      _SensorInfo(
        id: 'emg_2',
        label: 'EMG 2',
        position: '어깨',
        top: 96,
        right: 54,
      ),
      _SensorInfo(
        id: 'emg_3',
        label: 'EMG 3',
        position: '삼두',
        top: 56,
        right: 86,
      ),
      _SensorInfo(
        id: 'imu_1',
        label: 'IMU',
        position: '상부 등',
        top: 132,
        left: 112,
      ),
    ],
  ),
  'lateral_raise': _SensorConfig(
    title: '사이드 레터럴 레이즈',
    sensors: [
      _SensorInfo(
        id: 'emg_1',
        label: 'EMG 1',
        position: '측면 삼각근',
        top: 64,
        right: 56,
      ),
      _SensorInfo(
        id: 'emg_2',
        label: 'EMG 2',
        position: '상부 승모근',
        top: 44,
        left: 108,
      ),
      _SensorInfo(
        id: 'emg_3',
        label: 'EMG 3',
        position: '후면 어깨',
        top: 72,
        left: 64,
      ),
      _SensorInfo(
        id: 'imu_1',
        label: 'IMU',
        position: '손목',
        top: 148,
        right: 42,
      ),
    ],
  ),
  'bicep_curl': _SensorConfig(
    title: '바이셉 컬',
    sensors: [
      _SensorInfo(
        id: 'emg_1',
        label: 'EMG 1',
        position: '이두',
        top: 104,
        left: 54,
      ),
      _SensorInfo(
        id: 'emg_2',
        label: 'EMG 2',
        position: '전완',
        top: 148,
        left: 46,
      ),
      _SensorInfo(
        id: 'emg_3',
        label: 'EMG 3',
        position: '어깨',
        top: 80,
        right: 58,
      ),
      _SensorInfo(
        id: 'imu_1',
        label: 'IMU',
        position: '손목',
        top: 150,
        right: 46,
      ),
    ],
  ),
};
