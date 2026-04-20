import 'package:flutter/material.dart';

import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../widgets/ui/section_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsService();

  Future<void> _editGoal({
    required String title,
    required int current,
    required int min,
    required int max,
    int step = 1,
    required String unit,
    required Future<void> Function(int) onSave,
  }) async {
    int value = current;
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$value$unit',
                  style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    onPressed: value > min
                        ? () => setS(() => value = (value - step).clamp(min, max))
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  const SizedBox(width: 24),
                  IconButton.filledTonal(
                    onPressed: value < max
                        ? () => setS(() => value = (value + step).clamp(min, max))
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, value),
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
    if (result != null) await onSave(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── 운동 피드백 ──
            const _SectionHeader(title: '운동 피드백'),
            SectionCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.record_voice_over,
                        color: AppTheme.primary),
                    title: const Text('음성 안내 (TTS)'),
                    subtitle: const Text('반복 수, 자세 교정 등을 음성으로 안내'),
                    value: _settings.ttsEnabled,
                    activeTrackColor: AppTheme.primary,
                    onChanged: (v) async {
                      await _settings.setTtsEnabled(v);
                      setState(() {});
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.vibration,
                        color: AppTheme.primary),
                    title: const Text('진동 피드백'),
                    subtitle: const Text('반복 완료, 보상동작 감지 시 진동'),
                    value: _settings.hapticEnabled,
                    activeTrackColor: AppTheme.primary,
                    onChanged: (v) async {
                      await _settings.setHapticEnabled(v);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── 주간 목표 ──
            const _SectionHeader(title: '주간 목표'),
            SectionCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.flag_outlined,
                        color: AppTheme.primary),
                    title: const Text('주간 운동 횟수'),
                    trailing: Text('${_settings.weeklySessionGoal}회',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    onTap: () => _editGoal(
                      title: '주간 운동 횟수',
                      current: _settings.weeklySessionGoal,
                      min: 1,
                      max: 14,
                      unit: '회',
                      onSave: (v) async {
                        await _settings.setWeeklySessionGoal(v);
                        setState(() {});
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.repeat,
                        color: AppTheme.primary),
                    title: const Text('주간 반복 횟수'),
                    trailing: Text('${_settings.weeklyRepGoal}회',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    onTap: () => _editGoal(
                      title: '주간 반복 횟수',
                      current: _settings.weeklyRepGoal,
                      min: 10,
                      max: 2000,
                      step: 10,
                      unit: '회',
                      onSave: (v) async {
                        await _settings.setWeeklyRepGoal(v);
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── 단위 설정 ──
            const _SectionHeader(title: '단위'),
            SectionCard(
              padding: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.straighten, color: AppTheme.primary),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text('체중 단위',
                          style: TextStyle(fontSize: 16)),
                    ),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'kg', label: Text('kg')),
                        ButtonSegment(value: 'lb', label: Text('lb')),
                      ],
                      selected: {_settings.unit},
                      onSelectionChanged: (v) async {
                        await _settings.setUnit(v.first);
                        setState(() {});
                      },
                      style: ButtonStyle(
                        backgroundColor:
                            WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return AppTheme.primary;
                          }
                          return null;
                        }),
                        foregroundColor:
                            WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return Colors.white;
                          }
                          return AppTheme.textPrimary;
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── 테마 ──
            const _SectionHeader(title: '테마'),
            SectionCard(
              padding: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.brightness_6, color: AppTheme.primary),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text('다크 모드',
                          style: TextStyle(fontSize: 16)),
                    ),
                    SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                            value: ThemeMode.system, label: Text('시스템')),
                        ButtonSegment(
                            value: ThemeMode.light, label: Text('라이트')),
                        ButtonSegment(
                            value: ThemeMode.dark, label: Text('다크')),
                      ],
                      selected: {_settings.themeMode.value},
                      onSelectionChanged: (v) async {
                        await _settings.setThemeMode(v.first);
                        setState(() {});
                      },
                      style: ButtonStyle(
                        backgroundColor:
                            WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return AppTheme.primary;
                          }
                          return null;
                        }),
                        foregroundColor:
                            WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return Colors.white;
                          }
                          return null;
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── 앱 정보 ──
            const _SectionHeader(title: '앱 정보'),
            SectionCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  ListTile(
                    leading:
                        const Icon(Icons.info_outline, color: AppTheme.primary),
                    title: const Text('버전'),
                    trailing: const Text('1.0.0',
                        style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.description_outlined,
                        color: AppTheme.primary),
                    title: const Text('오픈소스 라이선스'),
                    trailing: const Icon(Icons.chevron_right,
                        color: AppTheme.textSecondary),
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'Inside Muscle Out',
                      applicationVersion: '1.0.0',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(
        left: AppTokens.space4,
        bottom: AppTokens.space12,
      ),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: isDark
              ? AppTheme.textSecondaryDark
              : AppTheme.textSecondary,
        ),
      ),
    );
  }
}
