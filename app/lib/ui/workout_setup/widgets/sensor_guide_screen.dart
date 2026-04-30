import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';

class SensorGuideScreen extends StatefulWidget {
  const SensorGuideScreen({super.key, this.exerciseId = 'pushup'});

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
      subtitle: '센서 부착 안내',
      showBackButton: true,
      onBack: () => context.go('/workout-plan?exercise=${widget.exerciseId}'),
      scrollable: true,
      bottom: ImoButton(
        label: _allChecked ? '캘리브레이션 시작' : '부착 확인 필요',
        disabled: !_allChecked,
        onPressed: _allChecked
            ? () => context.go(
                '/workout-calibration?exercise=${widget.exerciseId}&autoStart=true',
              )
            : null,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SensorMapCard(config: _config),
          const SizedBox(height: AppSpacing.sectionGap),
          Text('부착 확인', style: AppTextStyles.sectionTitle),
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
                label: '${config.sensors.length}개 센서',
                variant: StatusVariant.info,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            height: 360,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF5FF),
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(color: AppColors.border),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    Icons.accessibility_new_rounded,
                    size: 142,
                    color: AppColors.primary.withValues(alpha: 0.16),
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
  const _SensorMapMarker({required this.index, required this.sensor});

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
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.45),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  blurRadius: 0,
                  spreadRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.heatmapBg.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '$index. ${sensor.position}',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
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
      paddingSize: ImoCardPadding.lg,
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: checked ? AppColors.primary : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: checked ? AppColors.primary : AppColors.border,
                width: 2,
              ),
            ),
            child: checked
                ? const Icon(
                    Icons.check_rounded,
                    color: AppColors.card,
                    size: 20,
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sensor.position, style: AppTextStyles.sectionTitle),
                const SizedBox(height: AppSpacing.xxs),
                Text(sensor.label, style: AppTextStyles.body),
              ],
            ),
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
              Text('부착 전 주의사항', style: AppTextStyles.label),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const _NoticeLine('센서가 피부에 잘 밀착되었는지 확인하세요.'),
          const SizedBox(height: AppSpacing.xs),
          const _NoticeLine('운동 중 센서가 흔들리지 않도록 고정하세요.'),
          const SizedBox(height: AppSpacing.xs),
          const _NoticeLine('스마트글래스와 Pi 연결 상태를 확인하세요.'),
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
          padding: EdgeInsets.only(top: 7),
          child: Icon(Icons.circle, size: 5, color: AppColors.primaryStrong),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: Text(text, style: AppTextStyles.body)),
      ],
    );
  }
}

class _SensorConfig {
  const _SensorConfig({required this.title, required this.sensors});

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
        position: '대흉근',
        top: 104,
        left: 96,
      ),
      _SensorInfo(
        id: 'emg_2',
        label: 'EMG 2',
        position: '삼두근',
        top: 142,
        right: 42,
      ),
      _SensorInfo(
        id: 'emg_3',
        label: 'EMG 3',
        position: '전면 삼각근',
        top: 82,
        left: 134,
      ),
      _SensorInfo(
        id: 'imu_1',
        label: 'IMU',
        position: '등 중앙',
        top: 172,
        right: 64,
      ),
    ],
  ),
  'lateral_raise': _SensorConfig(
    title: '싸레레',
    sensors: [
      _SensorInfo(
        id: 'emg_1',
        label: 'EMG 1',
        position: '측면 삼각근',
        top: 92,
        right: 56,
      ),
      _SensorInfo(
        id: 'emg_2',
        label: 'EMG 2',
        position: '승모근',
        top: 62,
        left: 114,
      ),
      _SensorInfo(
        id: 'emg_3',
        label: 'EMG 3',
        position: '전면 삼각근',
        top: 128,
        left: 60,
      ),
      _SensorInfo(
        id: 'imu_1',
        label: 'IMU',
        position: '손목',
        top: 192,
        right: 46,
      ),
    ],
  ),
  'bicep_curl': _SensorConfig(
    title: '이두컬',
    sensors: [
      _SensorInfo(
        id: 'emg_1',
        label: 'EMG 1',
        position: '이두근',
        top: 136,
        left: 54,
      ),
      _SensorInfo(
        id: 'emg_2',
        label: 'EMG 2',
        position: '전완근',
        top: 186,
        left: 48,
      ),
      _SensorInfo(
        id: 'emg_3',
        label: 'EMG 3',
        position: '삼두근',
        top: 112,
        right: 58,
      ),
      _SensorInfo(
        id: 'imu_1',
        label: 'IMU',
        position: '손목',
        top: 206,
        right: 46,
      ),
    ],
  ),
};
