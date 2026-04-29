import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  bool _voiceCue = true;
  bool _hapticCue = true;
  bool _darkMode = false;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'My Page',
      subtitle: 'Profile and settings',
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileCard(onEdit: () => context.go('/profile-edit')),
          const SizedBox(height: AppSpacing.sectionGap),
          Text('Devices', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.sm),
          _DeviceStatusCard(onTap: () => context.go('/wearable-settings')),
          const SizedBox(height: AppSpacing.sectionGap),
          Text('App settings', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.sm),
          ImoCard(
            paddingSize: ImoCardPadding.none,
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.volume_up_rounded,
                  label: 'Voice cue',
                  trailing: Switch(
                    value: _voiceCue,
                    activeThumbColor: AppColors.primary,
                    onChanged: (value) => setState(() => _voiceCue = value),
                  ),
                ),
                const Divider(height: 1, color: AppColors.divider),
                _SettingsRow(
                  icon: Icons.vibration_rounded,
                  label: 'Haptic cue',
                  trailing: Switch(
                    value: _hapticCue,
                    activeThumbColor: AppColors.primary,
                    onChanged: (value) => setState(() => _hapticCue = value),
                  ),
                ),
                const Divider(height: 1, color: AppColors.divider),
                _SettingsRow(
                  icon: Icons.dark_mode_rounded,
                  label: 'Dark mode',
                  trailing: Switch(
                    value: _darkMode,
                    activeThumbColor: AppColors.primary,
                    onChanged: (value) => setState(() => _darkMode = value),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          Text('Account', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.sm),
          ImoCard(
            paddingSize: ImoCardPadding.none,
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.info_outline_rounded,
                  label: 'App version',
                  trailing: Text('1.0.0', style: AppTextStyles.caption),
                ),
                const Divider(height: 1, color: AppColors.divider),
                _SettingsRow(
                  icon: Icons.delete_outline_rounded,
                  label: 'Clear local history',
                  danger: true,
                  onTap: () => _showSimpleDialog(
                    context,
                    title: 'Clear local history',
                    message: 'This will clear local workout history later.',
                  ),
                ),
                const Divider(height: 1, color: AppColors.divider),
                _SettingsRow(
                  icon: Icons.logout_rounded,
                  label: 'Log out',
                  onTap: () => _showSimpleDialog(
                    context,
                    title: 'Log out',
                    message: 'Login flow will be connected later.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSimpleDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.onEdit});

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      variant: ImoCardVariant.hero,
      paddingSize: ImoCardPadding.lg,
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: AppColors.cardSubtle,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              color: AppColors.textTertiary,
              size: 30,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('IMO User', style: AppTextStyles.sectionTitle),
                const SizedBox(height: AppSpacing.xxs),
                Text('28 · 170cm · 65kg', style: AppTextStyles.caption),
              ],
            ),
          ),
          ImoButton(
            label: 'Edit',
            size: ImoButtonSize.sm,
            variant: ImoButtonVariant.outline,
            fullWidth: false,
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

class _DeviceStatusCard extends StatelessWidget {
  const _DeviceStatusCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      paddingSize: ImoCardPadding.lg,
      interactive: true,
      onTap: onTap,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Wearable devices', style: AppTextStyles.label),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              StatusBadge(label: 'Pi standby', variant: StatusVariant.info),
              StatusBadge(
                label: 'ESP32 pending',
                variant: StatusVariant.neutral,
              ),
              StatusBadge(
                label: 'Glass pending',
                variant: StatusVariant.neutral,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.error : AppColors.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.body.copyWith(
                    color: danger ? AppColors.error : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              trailing ??
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textTertiary,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
