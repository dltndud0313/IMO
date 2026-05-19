import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/dependencies.dart';
import '../../../data/repositories/calibration_repository.dart';
import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';
import '../../stats/widgets/svg_body_heatmap_view.dart' show BodyGender;
import 'cropped_body_svg.dart';
import 'exercise_target_regions.dart'
    show exerciseDisplayName, findExerciseBodyCrop;

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

  Future<void> _startCalibration() async {
    try {
      await getIt<CalibrationRepository>().connect();
      if (mounted) {
        context.push(
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

  void _toggleAllSensors() {
    setState(() {
      if (_allChecked) {
        _checkedSensorIds.clear();
      } else {
        _checkedSensorIds.addAll(_config.sensors.map((s) => s.id));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '센서 부착 안내',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.go('/workout-plan?exercise=${widget.exerciseId}'),
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
          Row(
            children: [
              Text('부착 확인', style: AppTextStyles.sectionTitle),
              const Spacer(),
              TextButton(
                onPressed: _toggleAllSensors,
                child: Text(
                  _allChecked ? '모두 선택해제' : '모두 선택',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${_checkedSensorIds.length} / ${_config.sensors.length}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _SensorChecklistCard(
            sensors: _config.sensors,
            checkedIds: _checkedSensorIds,
            onToggle: _toggleSensor,
          ),
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
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: '센서 부착 위치 · '),
                      TextSpan(
                        text: exerciseDisplayName(exerciseId),
                        style: TextStyle(
                          color: AppColors.primaryStrong,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  style: AppTextStyles.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              StatusBadge(
                label: '${config.sensors.length}개',
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
            child: CroppedBodySvg(
              assetPath: bodySvgAssetPath(BodyGender.male, isBack: false),
              crop: crop,
              overlayBuilder: (context, svgWidth, svgHeight) {
                return Stack(
                  children: [
                    for (final sensor in config.sensors)
                      _SensorMapMarker(
                        sensor: sensor,
                        svgWidth: svgWidth,
                        svgHeight: svgHeight,
                      ),
                  ],
                );
              },
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
///
/// [svgWidth] / [svgHeight] 는 SVG 가 차지하는 픽셀 크기. sensor 의
/// bodyX/bodyY 비율 (0~1) 을 곱해 실제 픽셀 위치 계산.
class _SensorMapMarker extends StatelessWidget {
  const _SensorMapMarker({
    required this.sensor,
    required this.svgWidth,
    required this.svgHeight,
  });

  final _SensorInfo sensor;
  final double svgWidth;
  final double svgHeight;

  static const _markerSize = 30.0;

  @override
  Widget build(BuildContext context) {
    final color = _markerColor(sensor.id);
    final label = _markerLabel(sensor.id);
    // 마커 중심이 (bodyX * svgWidth, bodyY * svgHeight) 에 오도록
    // 마커 크기의 절반만큼 빼서 Positioned.
    return Positioned(
      left: sensor.bodyX * svgWidth - _markerSize / 2,
      top: sensor.bodyY * svgHeight - _markerSize / 2,
      child: Container(
        width: _markerSize,
        height: _markerSize,
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

/// 콤팩트 체크리스트 — 한 카드 안에 모든 센서 한 줄씩.
///
/// 각 row 는 [E1 색 동그라미] [위치명] [체크 아이콘] 구조.
/// 위 SVG 의 마커와 같은 색/약어로 매칭, 사용자가 어느 센서가 어디인지 즉시 파악.
class _SensorChecklistCard extends StatelessWidget {
  const _SensorChecklistCard({
    required this.sensors,
    required this.checkedIds,
    required this.onToggle,
  });

  final List<_SensorInfo> sensors;
  final Set<String> checkedIds;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      paddingSize: ImoCardPadding.none,
      child: Column(
        children: [
          for (var i = 0; i < sensors.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, color: AppColors.divider),
            _SensorCheckRow(
              sensor: sensors[i],
              checked: checkedIds.contains(sensors[i].id),
              onTap: () => onToggle(sensors[i].id),
            ),
          ],
        ],
      ),
    );
  }
}

class _SensorCheckRow extends StatelessWidget {
  const _SensorCheckRow({
    required this.sensor,
    required this.checked,
    required this.onTap,
  });

  final _SensorInfo sensor;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _markerColor(sensor.id);
    final label = _markerLabel(sensor.id);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            // 마커와 동일한 색/약어 동그라미
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
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
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                sensor.position,
                style: AppTextStyles.bodyLg.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 140),
              child: checked
                  ? const Icon(
                      Icons.check_circle_rounded,
                      key: ValueKey('checked'),
                      color: AppColors.success,
                      size: 24,
                    )
                  : const Icon(
                      Icons.radio_button_unchecked,
                      key: ValueKey('unchecked'),
                      color: AppColors.textTertiary,
                      size: 24,
                    ),
            ),
          ],
        ),
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

/// 센서 정보.
///
/// [bodyX], [bodyY] 는 SVG 바디 위 위치를 0~1 비율로 표현.
/// - bodyX: 0 = 좌측 끝, 0.5 = 중심, 1 = 우측 끝 (사용자 = 화면 기준)
/// - bodyY: 0 = 머리 꼭대기, 1 = 발 끝
///
/// SVG 좌표계 안에서 표현하므로 SVG 가 crop / zoom 되어도 마커가 같이 따라감.
class _SensorInfo {
  const _SensorInfo({
    required this.id,
    required this.label,
    required this.position,
    required this.bodyX,
    required this.bodyY,
  });

  final String id;
  final String label;
  final String position;
  final double bodyX;
  final double bodyY;
}

// 좌표는 v3 SVG viewBox (0 -80 724 1450) 안에서 0~1 비율.
// 신체 비율 기준 (viewBox 전체 1450 높이에서 -80 시작):
//   머리      0.00 ~ 0.13
//   목/어깨   0.13 ~ 0.20
//   가슴      0.25 ~ 0.35
//   팔 위쪽   0.30 ~ 0.40 (이두/삼두)
//   복부      0.40 ~ 0.55
//   전완      0.42 ~ 0.50
//   골반      0.55 ~ 0.62
const _sensorConfigs = {
  'pushup': _SensorConfig(
    title: '푸시업',
    sensors: [
      _SensorInfo(
        id: 'emg_1', label: 'EMG 1', position: '왼쪽 대흉근',
        bodyX: 0.40, bodyY: 0.28,
      ),
      _SensorInfo(
        id: 'emg_2', label: 'EMG 2', position: '오른쪽 대흉근',
        bodyX: 0.60, bodyY: 0.28,
      ),
      // 삼두근은 후면 근육이지만 전면 SVG 옆 팔 위치에 표시
      _SensorInfo(
        id: 'emg_3', label: 'EMG 3', position: '왼쪽 삼두근',
        bodyX: 0.23, bodyY: 0.32,
      ),
      _SensorInfo(
        id: 'emg_4', label: 'EMG 4', position: '오른쪽 삼두근',
        bodyX: 0.77, bodyY: 0.32,
      ),
      // 등 상부 중앙 — 전면에서는 목/어깨 사이 중앙
      _SensorInfo(
        id: 'imu_1', label: 'IMU 1', position: '등 상부 중앙',
        bodyX: 0.50, bodyY: 0.21,
      ),
      _SensorInfo(
        id: 'imu_2', label: 'IMU 2', position: '왼쪽 상완',
        bodyX: 0.21, bodyY: 0.36,
      ),
      _SensorInfo(
        id: 'imu_3', label: 'IMU 3', position: '오른쪽 상완',
        bodyX: 0.79, bodyY: 0.36,
      ),
    ],
  ),
  'lateral_raise': _SensorConfig(
    title: '사이드 레터럴 레이즈',
    sensors: [
      _SensorInfo(
        id: 'emg_1', label: 'EMG 1', position: '왼쪽 측면 삼각근',
        bodyX: 0.27, bodyY: 0.24,
      ),
      _SensorInfo(
        id: 'emg_2', label: 'EMG 2', position: '오른쪽 측면 삼각근',
        bodyX: 0.73, bodyY: 0.24,
      ),
      _SensorInfo(
        id: 'emg_3', label: 'EMG 3', position: '왼쪽 상부 승모근',
        bodyX: 0.42, bodyY: 0.17,
      ),
      _SensorInfo(
        id: 'emg_4', label: 'EMG 4', position: '오른쪽 상부 승모근',
        bodyX: 0.58, bodyY: 0.17,
      ),
      _SensorInfo(
        id: 'imu_1', label: 'IMU 1', position: '왼쪽 전완',
        bodyX: 0.16, bodyY: 0.46,
      ),
      _SensorInfo(
        id: 'imu_2', label: 'IMU 2', position: '오른쪽 전완',
        bodyX: 0.84, bodyY: 0.46,
      ),
      // 등 중앙 — 전면에서는 가슴 중앙
      _SensorInfo(
        id: 'imu_3', label: 'IMU 3', position: '등 중앙',
        bodyX: 0.50, bodyY: 0.30,
      ),
    ],
  ),
  'bicep_curl': _SensorConfig(
    title: '이두컬',
    sensors: [
      _SensorInfo(
        id: 'emg_1', label: 'EMG 1', position: '왼쪽 이두근',
        bodyX: 0.29, bodyY: 0.34,
      ),
      _SensorInfo(
        id: 'emg_2', label: 'EMG 2', position: '오른쪽 이두근',
        bodyX: 0.71, bodyY: 0.34,
      ),
      _SensorInfo(
        id: 'emg_3', label: 'EMG 3', position: '왼쪽 전완근',
        bodyX: 0.22, bodyY: 0.43,
      ),
      _SensorInfo(
        id: 'emg_4', label: 'EMG 4', position: '오른쪽 전완근',
        bodyX: 0.78, bodyY: 0.43,
      ),
      _SensorInfo(
        id: 'imu_1', label: 'IMU 1', position: '왼쪽 전완',
        bodyX: 0.18, bodyY: 0.51,
      ),
      _SensorInfo(
        id: 'imu_2', label: 'IMU 2', position: '오른쪽 전완',
        bodyX: 0.82, bodyY: 0.51,
      ),
      _SensorInfo(
        id: 'imu_3', label: 'IMU 3', position: '몸통',
        bodyX: 0.50, bodyY: 0.42,
      ),
    ],
  ),
};
