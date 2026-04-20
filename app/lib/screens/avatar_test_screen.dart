import 'package:flutter/material.dart';

import '../models/pose_data.dart';
import '../services/profile_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_painter.dart';
import 'home_screen.dart';

/// 저장된 포즈 데이터를 기반으로 아바타를 그리고
/// 채널 3개를 슬라이더로 테스트해볼 수 있는 화면.
class AvatarTestScreen extends StatefulWidget {
  /// true면 첫 온보딩에서 진입한 것 — 완료 시 홈으로 이동
  final bool fromOnboarding;
  const AvatarTestScreen({super.key, this.fromOnboarding = false});

  @override
  State<AvatarTestScreen> createState() => _AvatarTestScreenState();
}

class _AvatarTestScreenState extends State<AvatarTestScreen> {
  final _storage = ProfileStorage();
  PoseData? _pose;
  bool _loading = true;

  double _torso = 0;
  double _upperArm = 0;
  double _shoulder = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pose = await _storage.loadPose();
    if (!mounted) return;
    setState(() {
      _pose = pose;
      _loading = false;
    });
  }

  void _finishOnboarding() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 아바타'),
        automaticallyImplyLeading: !widget.fromOnboarding,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _pose == null
                ? const Center(child: Text('저장된 포즈 데이터가 없습니다'))
                : Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: CustomPaint(
                              painter: AvatarPainter(
                                pose: _pose!,
                                regions: {
                                  'torso': MuscleChannel(
                                    label: 'CH1',
                                    muscleName: '몸통',
                                    intensity: _torso,
                                  ),
                                  'upperArm': MuscleChannel(
                                    label: 'CH2',
                                    muscleName: '상완',
                                    intensity: _upperArm,
                                  ),
                                  'shoulder': MuscleChannel(
                                    label: 'CH3',
                                    muscleName: '어깨',
                                    intensity: _shoulder,
                                  ),
                                },
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _ChannelSlider(
                              label: '몸통 (torso)',
                              value: _torso,
                              onChanged: (v) => setState(() => _torso = v),
                            ),
                            _ChannelSlider(
                              label: '상완 (upperArm)',
                              value: _upperArm,
                              onChanged: (v) => setState(() => _upperArm = v),
                            ),
                            _ChannelSlider(
                              label: '어깨 (shoulder)',
                              value: _shoulder,
                              onChanged: (v) => setState(() => _shoulder = v),
                            ),
                            if (widget.fromOnboarding) ...[
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _finishOnboarding,
                                child: const Text('완료'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _ChannelSlider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  const _ChannelSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(Colors.blue, Colors.red, value)!;
    return Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              thumbColor: color,
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 1,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            '${(value * 100).round()}%',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}
