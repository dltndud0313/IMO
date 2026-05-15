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
  final _nicknameController = TextEditingController();
  final _birthYearController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  String? _currentPasswordError;
  String? _passwordError;
  String? _passwordConfirmError;
  String _gender = '여성';
  String? _profileLoadError;
  bool _submitting = false;
  bool _changingPassword = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _birthYearController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _currentPasswordController.dispose();
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
        _profileLoadError = null;
        _nicknameController.text = profile.nickname;
        _birthYearController.text =
            (DateTime.now().year - profile.age).toString();
        _heightController.text = profile.heightCm.round().toString();
        _weightController.text = profile.weightKg.round().toString();
        _gender = _genderLabel(profile.gender);
      });
    } catch (_) {
      if (mounted) {
        setState(() => _profileLoadError = '프로필 정보를 불러오지 못했습니다.');
      }
    }
  }

  Future<void> _saveProfile() async {
    final nickname = _nicknameController.text.trim();
    final birthYear = int.tryParse(_birthYearController.text);
    final height = double.tryParse(_heightController.text);
    final weight = double.tryParse(_weightController.text);
    final currentYear = DateTime.now().year;
    if (nickname.isEmpty ||
        birthYear == null ||
        birthYear < currentYear - 120 ||
        birthYear > currentYear ||
        height == null ||
        weight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필 정보를 확인해주세요.')),
      );
      return;
    }
    final age = currentYear - birthYear;

    setState(() => _submitting = true);
    try {
      await getIt<UserProfileRepository>().updateProfile(
        UserProfile(
          nickname: nickname,
          age: age,
          gender: _genderCode,
          heightCm: height,
          weightKg: weight,
        ),
      );
      if (!mounted) {
        return;
      }
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/mypage');
      }
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

  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _passwordController.text;
    final confirmPassword = _passwordConfirmController.text;
    setState(() {
      _currentPasswordError =
          currentPassword.isEmpty ? '현재 비밀번호를 입력해주세요.' : null;
      _passwordError = newPassword == currentPassword
          ? '현재 비밀번호와 다른 비밀번호를 입력해주세요.'
          : _isWeakPassword(newPassword)
              ? '비밀번호가 너무 약해요. 영문과 숫자를 조합해주세요.'
              : null;
      _passwordConfirmError =
          newPassword != confirmPassword ? '비밀번호가 일치하지 않습니다.' : null;
    });
    if (_currentPasswordError != null ||
        _passwordError != null ||
        _passwordConfirmError != null) {
      return;
    }

    setState(() => _changingPassword = true);
    try {
      await getIt<UserProfileRepository>().changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      if (!mounted) {
        return;
      }
      _currentPasswordController.clear();
      _passwordController.clear();
      _passwordConfirmController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 변경되었습니다.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error.toString().contains('Current password is incorrect')
          ? '현재 비밀번호가 올바르지 않습니다.'
          : '비밀번호 변경에 실패했습니다.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _changingPassword = false);
      }
    }
  }

  bool _isWeakPassword(String password) {
    return password.isEmpty ||
        password.length < 8 ||
        !RegExp('[A-Za-z]').hasMatch(password) ||
        !RegExp(r'\d').hasMatch(password);
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
      onBack: () =>
          context.canPop() ? context.pop() : context.go('/mypage'),
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
              loading: _changingPassword,
              onPressed: _changingPassword ? null : _changePassword,
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
          if (_profileLoadError != null) ...[
            ImoCard(
              variant: ImoCardVariant.subtle,
              paddingSize: ImoCardPadding.md,
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.warning),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _profileLoadError!,
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          ImoCard(
            paddingSize: ImoCardPadding.none,
            child: Column(
              children: [
                _EditableRow(
                  label: '닉네임',
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
                _EditableRow(
                  label: '출생 년도',
                  child: ImoTextField(
                    controller: _birthYearController,
                    keyboardType: TextInputType.number,
                    suffixIcon: const Text('년'),
                  ),
                ),
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
                  label: '현재 비밀번호',
                  hint: '현재 비밀번호',
                  controller: _currentPasswordController,
                  errorText: _currentPasswordError,
                  obscureText: true,
                ),
                const SizedBox(height: AppSpacing.md),
                ImoTextField(
                  label: '새 비밀번호',
                  hint: '8자 이상 입력',
                  controller: _passwordController,
                  errorText: _passwordError,
                  obscureText: true,
                  onChanged: (value) => setState(() {
                    _passwordError = _isWeakPassword(value)
                        ? '비밀번호가 너무 약해요. 영문과 숫자를 조합해주세요.'
                        : null;
                  }),
                ),
                const SizedBox(height: AppSpacing.md),
                ImoTextField(
                  label: '새 비밀번호 확인',
                  hint: '새 비밀번호 재입력',
                  controller: _passwordConfirmController,
                  errorText: _passwordConfirmError,
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

