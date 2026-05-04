import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/dependencies.dart';
import '../../../data/repositories/user_profile_repository.dart';
import '../../../domain/models/user_profile.dart';
import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _nicknameController = TextEditingController(text: 'x');
  final _heightController = TextEditingController(text: '170');
  final _weightController = TextEditingController(text: '65');
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  String _gender = '여성';
  UserProfile? _profile;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await getIt<UserProfileRepository>().getProfile(
        forceRefresh: true,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = profile;
        _nicknameController.text = profile.nickname;
        _heightController.text = profile.heightCm.round().toString();
        _weightController.text = profile.weightKg.round().toString();
        _gender = _genderLabel(profile.gender);
      });
    } catch (_) {
      // Keep the existing placeholder values when profile loading fails.
    }
  }

  Future<void> _saveProfile() async {
    final nickname = _nicknameController.text.trim();
    final height = double.tryParse(_heightController.text);
    final weight = double.tryParse(_weightController.text);
    if (nickname.isEmpty || height == null || weight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필 정보를 확인해주세요.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await getIt<UserProfileRepository>().updateProfile(
        UserProfile(
          nickname: nickname,
          age: _profile?.age ?? 31,
          gender: _genderCode,
          heightCm: height,
          weightKg: weight,
        ),
      );
      if (!mounted) {
        return;
      }
      context.go('/mypage');
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필 수정에 실패했습니다.')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String get _genderCode {
    return switch (_gender) {
      '남성' => 'MALE',
      '여성' => 'FEMALE',
      _ => 'OTHER',
    };
  }

  String _genderLabel(String code) {
    return switch (code) {
      'MALE' => '남성',
      'FEMALE' => '여성',
      _ => '기타',
    };
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '프로필 수정',
      showBackButton: true,
      onBack: () => context.go('/mypage'),
      scrollable: true,
      bottom: Row(
        children: [
          Expanded(
            child: ImoButton(
              label: '프로필 수정',
              loading: _submitting,
              disabled: _submitting,
              onPressed: _submitting ? null : _saveProfile,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: ImoButton(
              label: '비밀번호 변경',
              variant: ImoButtonVariant.secondary,
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: const BoxDecoration(
                  color: AppColors.cardSubtle,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.textTertiary,
                  size: 44,
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.card, width: 4),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: AppColors.card,
                  size: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ImoCard(
            paddingSize: ImoCardPadding.none,
            child: Column(
              children: [
                _EditableRow(
                  label: '이름',
                  child: ImoTextField(
                    controller: _nicknameController,
                    hint: '닉네임',
                    clearable: true,
                  ),
                ),
                const Divider(height: 1, color: AppColors.divider),
                _EditableRow(
                  label: '성별',
                  child: Wrap(
                    spacing: AppSpacing.xs,
                    children: [
                      for (final gender in const ['남성', '여성', '기타'])
                        ImoChip(
                          label: gender,
                          selected: _gender == gender,
                          onTap: () => setState(() => _gender = gender),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.divider),
                const _InfoRow(label: '생년월일', value: '1995'),
                const Divider(height: 1, color: AppColors.divider),
                Row(
                  children: [
                    Expanded(
                      child: _EditableRow(
                        label: '키',
                        child: ImoTextField(
                          controller: _heightController,
                          keyboardType: TextInputType.number,
                          suffixIcon: const Text('cm'),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _EditableRow(
                        label: '몸무게',
                        child: ImoTextField(
                          controller: _weightController,
                          keyboardType: TextInputType.number,
                          suffixIcon: const Text('kg'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ImoCard(
            paddingSize: ImoCardPadding.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('비밀번호', style: AppTextStyles.label),
                const SizedBox(height: AppSpacing.md),
                ImoTextField(
                  label: '비밀번호',
                  hint: '새 비밀번호',
                  controller: _passwordController,
                  obscureText: true,
                ),
                const SizedBox(height: AppSpacing.md),
                ImoTextField(
                  label: '비밀번호 확인',
                  hint: '비밀번호 재입력',
                  controller: _passwordConfirmController,
                  obscureText: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableRow extends StatelessWidget {
  const _EditableRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.xs),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Text(label, style: AppTextStyles.body),
          const Spacer(),
          Text(value, style: AppTextStyles.label),
        ],
      ),
    );
  }
}
