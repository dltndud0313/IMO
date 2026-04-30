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
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _emailError = _validateEmail(email);
      _passwordError = _validatePassword(password);
    });

    if (_emailError == null && _passwordError == null) {
      context.go('/home');
    }
  }

  String? _validateEmail(String value) {
    if (value.isEmpty) {
      return '이메일을 입력해주세요.';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
      return '올바른 이메일 형식으로 입력해주세요.';
    }
    return null;
  }

  String? _validatePassword(String value) {
    if (value.isEmpty) {
      return '비밀번호를 입력해주세요.';
    }
    if (value.length < 8) {
      return '비밀번호는 8자 이상 입력해주세요.';
    }
    return null;
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
            errorText: _emailError,
            onChanged: (_) {
              if (_emailError != null) {
                setState(() => _emailError = null);
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          ImoTextField(
            label: '비밀번호',
            hint: '비밀번호를 입력하세요',
            controller: _passwordController,
            obscureText: true,
            errorText: _passwordError,
            onChanged: (_) {
              if (_passwordError != null) {
                setState(() => _passwordError = null);
              }
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          ImoButton(label: '로그인', onPressed: _submit),
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
