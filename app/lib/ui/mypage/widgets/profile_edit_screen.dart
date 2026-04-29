import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _nicknameController = TextEditingController(text: 'IMO 사용자');
  final _heightController = TextEditingController(text: '170');
  final _weightController = TextEditingController(text: '65');
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  String _gender = '여성';

  @override
  void dispose() {
    _nicknameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '프로필 수정',
      showBackButton: true,
      scrollable: true,
      bottom: Row(
        children: [
          Expanded(
            child: ImoButton(
              label: '프로필 저장',
              onPressed: () => context.pop(),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: ImoButton(
              label: '비밀번호 저장',
              variant: ImoButtonVariant.outline,
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ImoCard(
            paddingSize: ImoCardPadding.lg,
            child: Column(
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
                        Icons.person_rounded,
                        color: AppColors.textTertiary,
                        size: 42,
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: AppColors.card,
                        size: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                ImoTextField(
                  label: '닉네임',
                  hint: '닉네임을 입력해 주세요',
                  controller: _nicknameController,
                  clearable: true,
                ),
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('성별', style: AppTextStyles.label),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    for (final gender in const ['여성', '남성', '기타'])
                      ImoChip(
                        label: gender,
                        selected: _gender == gender,
                        onTap: () => setState(() => _gender = gender),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: ImoTextField(
                        label: '키',
                        hint: 'cm',
                        controller: _heightController,
                        keyboardType: TextInputType.number,
                        suffixIcon: const Text('cm'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ImoTextField(
                        label: '몸무게',
                        hint: 'kg',
                        controller: _weightController,
                        keyboardType: TextInputType.number,
                        suffixIcon: const Text('kg'),
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
                  label: '새 비밀번호',
                  controller: _passwordController,
                  obscureText: true,
                ),
                const SizedBox(height: AppSpacing.md),
                ImoTextField(
                  label: '비밀번호 확인',
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
