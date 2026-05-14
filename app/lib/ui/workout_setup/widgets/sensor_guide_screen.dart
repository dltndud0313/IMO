import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/dependencies.dart';
import '../../../data/repositories/calibration_repository.dart';
import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';
import '../../stats/widgets/svg_body_heatmap_view.dart' show BodyGender;
import '../view_model/workout_setup_viewmodel.dart';
import 'cropped_body_svg.dart';
import 'exercise_target_regions.dart' show findExerciseBodyCrop;

class SensorGuideScreen extends StatefulWidget {
  const SensorGuideScreen({super.key, this.exerciseId = 'pushup'});

  final String exerciseId;

  @override
  State<SensorGuideScreen> createState() => _SensorGuideScreenState();
}

class _SensorGuideScreenState extends State<SensorGuideScreen> {
  final Set<String> _checkedSensorIds = {};
  late final WorkoutSetupViewModel _viewModel;

  _SensorConfig get _config =>
      _sensorConfigs[widget.exerciseId] ?? _sensorConfigs['pushup']!;

  bool get _allChecked =>
      _config.sensors.every((sensor) => _checkedSensorIds.contains(sensor.id));

  @override
  void initState() {
    super.initState();
    _viewModel = WorkoutSetupViewModel.withCalibration(
      getIt<CalibrationRepository>(),
    );
  }

  Future<void> _startCalibration() async {
    try {
      await _viewModel.completeSensorAttachmentAndStartCalibration(
        exerciseType: widget.exerciseId,
      );
      if (mounted) {
        context.go(
          '/workout-calibration?exercise=${widget.exerciseId}&autoStart=true',
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Pi connection failed.')));
      }
    }
  }

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
      title: '센서 부착 안내',
      showBackButton: true,
      onBack: () => context.go('/workout-plan?exercise=${widget.exerciseId}'),
      scrollable: true,
      bottom: ImoButton(
        label: _allChecked ? '캘리브레이션 시작' : '부착 확인 필요',
        disabled: !_allChecked,
        onPressed: _allChecked ? _startCalibration : null,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SensorMapCard(config: _config, exerciseId: widget.exerciseId),
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
  const _SensorMapCard({required this.config, required this.exerciseId});

  final _SensorConfig config;
  final String exerciseId;

  @override
  Widget build(BuildContext context) {
    final crop = findExerciseBodyCrop(exerciseId);
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
          const SizedBox(height: AppSpacing.sm),
          // EMG/IMU 범례
          Row(
            children: const [
              _LegendDot(color: _emgColor, label: 'EMG'),
              SizedBox(width: AppSpacing.md),
              _LegendDot(color: _imuColor, label: 'IMU'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
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
                Positioned.fill(
                  child: CroppedBodySvg(
                    assetPath: bodySvgAssetPath(
                      BodyGender.male,
                      isBack: false,
                    ),
                    crop: crop,
                  ),
                ),
                for (final sensor in config.sensors)
                  _SensorMapMarker(sensor: sensor),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const Color _emgColor = AppColors.primaryStrong; // 파랑 계열
const Color _imuColor = AppColors.warning; // 주황 계열

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xxs),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}

/// 센서 부착 위치 마커. SVG 바디 위에 오버레이로 표시.
///
/// 디자인 B안: 동그라미 안에 약어+숫자 ("E1", "I2"), EMG/IMU 색상 구분.
class _SensorMapMarker extends StatelessWidget {
  const _SensorMapMarker({required this.sensor});

  final _SensorInfo sensor;

  @override
  Widget build(BuildContext context) {
    final color = _markerColor(sensor.id);
    final label = _markerLabel(sensor.id);
    return Positioned(
      top: sensor.top,
      left: sensor.left,
      right: sensor.right,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.card, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.card,
            fontWeight: FontWeight.w800,
            fontSize: 11,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

/// 센서 id (`emg_1`, `imu_2`) → 마커 라벨 (`E1`, `I2`).
String _markerLabel(String sensorId) {
  if (sensorId.startsWith('emg_')) {
    return 'E${sensorId.substring(4)}';
  }
  if (sensorId.startsWith('imu_')) {
    return 'I${sensorId.substring(4)}';
  }
  return sensorId.toUpperCase();
}

/// 센서 id → 마커 색상. EMG=파랑 계열, IMU=주황 계열.
Color _markerColor(String sensorId) {
  if (sensorId.startsWith('imu_')) return _imuColor;
  return _emgColor;
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
        position: '왼쪽 대흉근',
        top: 104,
        left: 96,
      ),
      _SensorInfo(
        id: 'emg_2',
        label: 'EMG 2',
        position: '오른쪽 대흉근',
        top: 142,
        right: 42,
      ),
      _SensorInfo(
        id: 'emg_3',
        label: 'EMG 3',
        position: '왼쪽 삼두근',
        top: 82,
        left: 134,
      ),
      _SensorInfo(
        id: 'emg_4',
        label: 'EMG 4',
        position: '오른쪽 삼두근',
        top: 118,
        right: 96,
      ),
      _SensorInfo(
        id: 'imu_1',
        label: 'IMU 1',
        position: '등 상부 중앙',
        top: 172,
        right: 64,
      ),
      _SensorInfo(
        id: 'imu_2',
        label: 'IMU 2',
        position: '왼쪽 상완',
        top: 218,
        left: 56,
      ),
      _SensorInfo(
        id: 'imu_3',
        label: 'IMU 3',
        position: '오른쪽 상완',
        top: 218,
        right: 56,
      ),
    ],
  ),
  'lateral_raise': _SensorConfig(
    title: '사이드 레터럴 레이즈',
    sensors: [
      _SensorInfo(
        id: 'emg_1',
        label: 'EMG 1',
        position: '왼쪽 측면 삼각근',
        top: 92,
        left: 56,
      ),
      _SensorInfo(
        id: 'emg_2',
        label: 'EMG 2',
        position: '오른쪽 측면 삼각근',
        top: 92,
        right: 56,
      ),
      _SensorInfo(
        id: 'emg_3',
        label: 'EMG 3',
        position: '왼쪽 상부 승모근',
        top: 62,
        left: 114,
      ),
      _SensorInfo(
        id: 'emg_4',
        label: 'EMG 4',
        position: '오른쪽 상부 승모근',
        top: 62,
        right: 114,
      ),
      _SensorInfo(
        id: 'imu_1',
        label: 'IMU 1',
        position: '왼쪽 전완',
        top: 192,
        left: 46,
      ),
      _SensorInfo(
        id: 'imu_2',
        label: 'IMU 2',
        position: '오른쪽 전완',
        top: 192,
        right: 46,
      ),
      _SensorInfo(
        id: 'imu_3',
        label: 'IMU 3',
        position: '등 중앙',
        top: 150,
        right: 92,
      ),
    ],
  ),
  'bicep_curl': _SensorConfig(
    title: '이두컬',
    sensors: [
      _SensorInfo(
        id: 'emg_1',
        label: 'EMG 1',
        position: '왼쪽 이두근',
        top: 136,
        left: 54,
      ),
      _SensorInfo(
        id: 'emg_2',
        label: 'EMG 2',
        position: '오른쪽 이두근',
        top: 136,
        right: 54,
      ),
      _SensorInfo(
        id: 'emg_3',
        label: 'EMG 3',
        position: '왼쪽 전완근',
        top: 186,
        left: 48,
      ),
      _SensorInfo(
        id: 'emg_4',
        label: 'EMG 4',
        position: '오른쪽 전완근',
        top: 186,
        right: 48,
      ),
      _SensorInfo(
        id: 'imu_1',
        label: 'IMU 1',
        position: '왼쪽 전완',
        top: 206,
        left: 46,
      ),
      _SensorInfo(
        id: 'imu_2',
        label: 'IMU 2',
        position: '오른쪽 전완',
        top: 206,
        right: 46,
      ),
      _SensorInfo(
        id: 'imu_3',
        label: 'IMU 3',
        position: '몸통',
        top: 112,
        right: 58,
      ),
    ],
  ),
};
