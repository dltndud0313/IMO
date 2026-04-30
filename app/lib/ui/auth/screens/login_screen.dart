import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';
import '../widgets/auth_frame.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthFrame(
      topFlex: 6,
      sheetPadding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
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
            hint: '비밀번호를 입력하세요',
            controller: _passwordController,
            obscureText: true,
          ),
          const SizedBox(height: AppSpacing.xl),
          ImoButton(label: '로그인', onPressed: () => context.go('/home')),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => context.go('/signup'),
                child: Text(
                  '가입하기',
                  style: AppTextStyles.bodyLg.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                '|',
                style: AppTextStyles.body.copyWith(color: AppColors.divider),
              ),
              TextButton(
                onPressed: () => context.go('/splash'),
                child: Text(
                  '뒤로',
                  style: AppTextStyles.bodyLg.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
