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
  final _nicknameController = TextEditingController(text: 'x');
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
            child: ImoButton(label: '프로필 수정', onPressed: () => context.pop()),
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
