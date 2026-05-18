import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/dependencies.dart';
import '../../../data/repositories/auth_repository.dart';
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
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _passwordConfirmFocusNode = FocusNode();
  Timer? _emailCheckTimer;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;
  bool? _emailAvailable;
  bool _checkingEmail = false;
  final bool _submitting = false;

  @override
  void dispose() {
    _emailCheckTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _passwordConfirmFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _passwordConfirmController.text;

    setState(() {
      _emailError = _validateEmail(email);
      _passwordError = _validatePassword(password);
      _confirmError = _validateConfirm(password, confirm);
    });

    if (_emailError != null || _passwordError != null || _confirmError != null) {
      return;
    }
    if (!await _checkEmailAvailability(email)) {
      return;
    }
    if (!mounted) return;
    // 실제 가입은 프로필 설정 마지막 "가입 완료"에서 수행한다.
    context.push(
      '/profile-setup',
      extra: {'email': email, 'password': password},
    );
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
    if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d).+$').hasMatch(value)) {
      return '비밀번호는 영문과 숫자를 함께 입력해주세요.';
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

  void _handleEmailChanged(String value) {
    _emailCheckTimer?.cancel();
    final email = value.trim();
    setState(() {
      _emailError = null;
      _emailAvailable = null;
      _checkingEmail = false;
    });

    if (_validateEmail(email) != null) {
      return;
    }

    _emailCheckTimer = Timer(const Duration(milliseconds: 600), () {
      _checkEmailAvailability(email);
    });
  }

  Future<bool> _checkEmailAvailability(String email) async {
    if (!mounted) {
      return false;
    }
    setState(() {
      _checkingEmail = true;
      _emailError = null;
    });

    try {
      final available = await getIt<AuthRepository>().checkEmailAvailable(email);
      if (!mounted || _emailController.text.trim() != email) {
        return false;
      }
      setState(() {
        _checkingEmail = false;
        _emailAvailable = available;
        _emailError = available ? null : '이미 사용 중인 이메일입니다.';
      });
      return available;
    } catch (_) {
      if (!mounted || _emailController.text.trim() != email) {
        return false;
      }
      setState(() {
        _checkingEmail = false;
        _emailAvailable = null;
        _emailError = '이메일 중복 확인에 실패했습니다.';
      });
      return false;
    }
  }

  String? get _emailHelperText {
    if (_checkingEmail) {
      return '이메일 중복 확인 중입니다.';
    }
    if (_emailAvailable == true && _emailError == null) {
      return '사용 가능한 이메일입니다.';
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
            focusNode: _emailFocusNode,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _passwordFocusNode.requestFocus(),
            clearable: true,
            errorText: _emailError,
            helperText: _emailHelperText,
            helperColor: _emailAvailable == true ? AppColors.success : null,
            suffixIcon: _emailAvailable == true
                ? const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                  )
                : null,
            pill: true,
            onChanged: _handleEmailChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          ImoTextField(
            label: '비밀번호',
            hint: '8자 이상 입력',
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _passwordConfirmFocusNode.requestFocus(),
            obscureText: true,
            errorText: _passwordError,
            pill: true,
            onChanged: (_) => _clearErrors(),
          ),
          const SizedBox(height: AppSpacing.md),
          ImoTextField(
            label: '비밀번호 확인',
            hint: '비밀번호 재입력',
            controller: _passwordConfirmController,
            focusNode: _passwordConfirmFocusNode,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              _passwordConfirmFocusNode.unfocus();
              _submit();
            },
            obscureText: true,
            errorText: _confirmError,
            pill: true,
            onChanged: (_) => _clearErrors(),
          ),
          const SizedBox(height: AppSpacing.xl),
          ImoButton(
            label: '가입하기',
            loading: _submitting,
            disabled: _submitting || _checkingEmail || _emailAvailable == false,
            pill: true,
            onPressed: (_submitting || _checkingEmail || _emailAvailable == false)
                ? null
                : _submit,
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: TextButton(
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go('/login'),
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
