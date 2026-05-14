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
  bool _voiceCue = false;
  bool _hapticCue = false;
  UserProfile? _profile;
  bool _profileLoading = true;
  String? _profileLoadError;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _profileLoading = true;
      _profileLoadError = null;
    });
    try {
      final profile = await getIt<UserProfileRepository>().getProfile(
        forceRefresh: true,
      );
      if (mounted) {
        setState(() {
          _profile = profile;
          _profileLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _profileLoading = false;
          _profileLoadError = '프로필 정보를 불러오지 못했습니다.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      nested: true,
      title: '마이페이지',
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileCard(
            profile: _profile,
            loading: _profileLoading,
            onEdit: () => context.go('/profile-edit'),
          ),
          if (_profileLoadError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _ProfileErrorCard(
              message: _profileLoadError!,
              onRetry: _loadProfile,
            ),
          ],
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
                  icon: Icons.article_outlined,
                  label: '오픈소스 라이선스',
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'IMO',
                    applicationVersion: '1.1.1',
                  ),
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
  const _ProfileCard({
    required this.profile,
    required this.loading,
    required this.onEdit,
  });

  final UserProfile? profile;
  final bool loading;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      variant: ImoCardVariant.hero,
      paddingSize: ImoCardPadding.lg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
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
                      loading ? '불러오는 중' : profile?.nickname ?? '프로필 없음',
                      style: AppTextStyles.sectionTitle,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      loading ? '프로필 정보를 확인하고 있어요' : _profileSummary,
                      style: AppTextStyles.body,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '프로필 수정',
                onPressed: onEdit,
                icon: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.textTertiary,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String get _profileSummary {
    final currentProfile = profile;
    if (currentProfile == null) {
      return '프로필 정보를 불러오지 못했습니다';
    }
    final genderLabel = switch (currentProfile.gender) {
      'MALE' => '남성',
      'FEMALE' => '여성',
      _ => '기타',
    };
    return '만 ${currentProfile.age}세 $genderLabel '
        '${currentProfile.heightCm.round()}cm '
        '${currentProfile.weightKg.round()}kg';
  }
}

class _ProfileErrorCard extends StatelessWidget {
  const _ProfileErrorCard({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      variant: ImoCardVariant.subtle,
      paddingSize: ImoCardPadding.md,
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message, style: AppTextStyles.bodySmall)),
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
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
