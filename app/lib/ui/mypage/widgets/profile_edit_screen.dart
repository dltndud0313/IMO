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
  final _nicknameController = TextEditingController(text: 'IMO User');
  final _heightController = TextEditingController(text: '170');
  final _weightController = TextEditingController(text: '65');
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  String _gender = 'Female';

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
      title: 'Edit Profile',
      showBackButton: true,
      scrollable: true,
      bottom: Row(
        children: [
          Expanded(
            child: ImoButton(
              label: 'Save profile',
              onPressed: () => context.pop(),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: ImoButton(
              label: 'Save password',
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
                  label: 'Nickname',
                  hint: 'Enter nickname',
                  controller: _nicknameController,
                  clearable: true,
                ),
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Gender', style: AppTextStyles.label),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    for (final gender in const ['Female', 'Male', 'Other'])
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
                        label: 'Height',
                        hint: 'cm',
                        controller: _heightController,
                        keyboardType: TextInputType.number,
                        suffixIcon: const Text('cm'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ImoTextField(
                        label: 'Weight',
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
                Text('Password', style: AppTextStyles.label),
                const SizedBox(height: AppSpacing.md),
                ImoTextField(
                  label: 'New password',
                  controller: _passwordController,
                  obscureText: true,
                ),
                const SizedBox(height: AppSpacing.md),
                ImoTextField(
                  label: 'Confirm password',
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
