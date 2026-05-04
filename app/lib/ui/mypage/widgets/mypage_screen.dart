import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_settings.dart';
import '../../../config/dependencies.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/user_profile_repository.dart';
import '../../../domain/models/user_profile.dart';
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
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await getIt<UserProfileRepository>().getProfile(
        forceRefresh: true,
      );
      if (mounted) {
        setState(() => _profile = profile);
      }
    } catch (_) {
      // Keep the existing placeholder when profile loading fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '마이페이지',
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileCard(
            profile: _profile,
            onEdit: () => context.go('/profile-edit'),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          Text('앱 설정', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.sm),
          ImoCard(
            paddingSize: ImoCardPadding.none,
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.volume_up_rounded,
                  label: '음성 피드백',
                  trailing: Switch(
                    value: _voiceCue,
                    activeThumbColor: AppColors.primary,
                    onChanged: (value) => setState(() => _voiceCue = value),
                  ),
                ),
                const Divider(height: 1, color: AppColors.divider),
                _SettingsRow(
                  icon: Icons.vibration_rounded,
                  label: '진동 피드백',
                  trailing: Switch(
                    value: _hapticCue,
                    activeThumbColor: AppColors.primary,
                    onChanged: (value) => setState(() => _hapticCue = value),
                  ),
                ),
                const Divider(height: 1, color: AppColors.divider),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: appThemeMode,
                  builder: (context, themeMode, _) {
                    return _SettingsRow(
                      icon: Icons.dark_mode_rounded,
                      label: '다크 모드',
                      trailing: Switch(
                        value: themeMode == ThemeMode.dark,
                        activeThumbColor: AppColors.primary,
                        onChanged: (value) {
                          appThemeMode.value = value
                              ? ThemeMode.dark
                              : ThemeMode.light;
                        },
                      ),
                    );
                  },
                ),
                const Divider(height: 1, color: AppColors.divider),
                _SettingsRow(
                  icon: Icons.delete_outline_rounded,
                  label: '데이터 초기화',
                  danger: true,
                  onTap: () => _showDataResetDialog(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          Text('앱 정보', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.sm),
          ImoCard(
            paddingSize: ImoCardPadding.none,
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.info_outline_rounded,
                  label: '앱 버전',
                  trailing: Text('1.1.1', style: AppTextStyles.caption),
                ),
                const Divider(height: 1, color: AppColors.divider),
                _SettingsRow(
                  icon: Icons.logout_rounded,
                  label: '로그아웃',
                  onTap: () => _showLogoutDialog(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDataResetDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => ImoConfirmDialog(
        message: '모든 운동 기록이 사라집니다.\n정말 초기화 하시겠습니까?',
        confirmLabel: '예',
        cancelLabel: '아니오',
        danger: true,
        onConfirm: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => ImoConfirmDialog(
        message: '로그아웃 하시겠습니까?',
        confirmLabel: '예',
        cancelLabel: '아니오',
        onConfirm: () async {
          Navigator.of(dialogContext).pop();
          await getIt<AuthRepository>().logout();
          getIt<UserProfileRepository>().clearCache();
          if (context.mounted) {
            context.go('/splash');
          }
        },
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.onEdit});

  final UserProfile? profile;
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
              Icons.person_outline_rounded,
              color: AppColors.textTertiary,
              size: 30,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.nickname ?? 'x',
                  style: AppTextStyles.sectionTitle,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(_profileSummary, style: AppTextStyles.body),
              ],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Text('프로필 수정', style: AppTextStyles.caption),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textTertiary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _profileSummary {
    final currentProfile = profile;
    if (currentProfile == null) {
      return '31세 여성 170cm 65kg';
    }
    final genderLabel = switch (currentProfile.gender) {
      'MALE' => '남성',
      'FEMALE' => '여성',
      _ => '기타',
    };
    return '${currentProfile.age}세 $genderLabel '
        '${currentProfile.heightCm.round()}cm '
        '${currentProfile.weightKg.round()}kg';
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
              Icon(icon, color: color, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyLg.copyWith(
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
