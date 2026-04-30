import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';
import '../widgets/auth_frame.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthFrame(
      topFlex: 5,
      sheetPadding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      sheet: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ImoTextField(
            label: '이메일',
            hint: 'example@email.com',
            keyboardType: TextInputType.emailAddress,
            controller: _emailController,
            clearable: true,
          ),
          const SizedBox(height: AppSpacing.md),
          ImoTextField(
            label: '비밀번호',
            hint: '8자 이상 입력',
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
          const SizedBox(height: AppSpacing.xl),
          ImoButton(
            label: '가입하기',
            onPressed: () => context.go('/profile-setup'),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: TextButton(
              onPressed: () => context.go('/login'),
              child: Text(
                '이미 계정이 있으신가요? 로그인하기',
                style: AppTextStyles.bodyLg.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
