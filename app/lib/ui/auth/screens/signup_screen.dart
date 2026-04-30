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
  String? _emailError;
  String? _passwordError;
  String? _confirmError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _passwordConfirmController.text;

    setState(() {
      _emailError = _validateEmail(email);
      _passwordError = _validatePassword(password);
      _confirmError = _validateConfirm(password, confirm);
    });

    if (_emailError == null && _passwordError == null && _confirmError == null) {
      context.go('/profile-setup');
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

  String? _validateConfirm(String password, String confirm) {
    if (confirm.isEmpty) {
      return '비밀번호 확인을 입력해주세요.';
    }
    if (password != confirm) {
      return '비밀번호가 일치하지 않습니다.';
    }
    return null;
  }

  void _clearErrors() {
    if (_emailError != null || _passwordError != null || _confirmError != null) {
      setState(() {
        _emailError = null;
        _passwordError = null;
        _confirmError = null;
      });
    }
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
            errorText: _emailError,
            onChanged: (_) => _clearErrors(),
          ),
          const SizedBox(height: AppSpacing.md),
          ImoTextField(
            label: '비밀번호',
            hint: '8자 이상 입력',
            controller: _passwordController,
            obscureText: true,
            errorText: _passwordError,
            onChanged: (_) => _clearErrors(),
          ),
          const SizedBox(height: AppSpacing.md),
          ImoTextField(
            label: '비밀번호 확인',
            hint: '비밀번호 재입력',
            controller: _passwordConfirmController,
            obscureText: true,
            errorText: _confirmError,
            onChanged: (_) => _clearErrors(),
          ),
          const SizedBox(height: AppSpacing.xl),
          ImoButton(
            label: '가입하기',
            onPressed: _submit,
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
