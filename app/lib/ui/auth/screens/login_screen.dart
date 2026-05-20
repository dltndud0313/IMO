import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/dependencies.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/user_profile_repository.dart';
import '../../../data/services/api_service.dart';
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
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  String? _emailError;
  String? _passwordError;
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _emailError = _validateEmail(email);
      _passwordError = _validatePassword(password);
    });

    if (_emailError != null || _passwordError != null) {
      return;
    }

    setState(() => _submitting = true);
    try {
      await getIt<AuthRepository>().login(email, password);
      getIt<UserProfileRepository>().clearCache();
      if (!mounted) {
        return;
      }
      context.go('/home');
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_authErrorMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
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
      return '비밀번호는 8자 이상이어야 합니다.';
    }
    if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d).+$').hasMatch(value)) {
      return '비밀번호는 영문과 숫자를 모두 포함해야 합니다.';
    }
    return null;
  }

  String _authErrorMessage(Object error) {
    final message = error.toString();
    if (message.contains('Network unavailable')) {
      return '네트워크 연결을 확인해주세요.';
    }
    if (message.contains('Incorrect email or password')) {
      return '이메일 또는 비밀번호가 올바르지 않습니다.';
    }
    if (message.contains('not authenticated') ||
        message.contains('Unauthorized')) {
      return '현재 연결된 로컬 서버에서 인증되지 않았습니다.';
    }
    return '로그인에 실패했습니다.';
  }

  @override
  Widget build(BuildContext context) {
    return AuthFrame(
      topFlex: 6,
      backgroundImage: const AssetImage('assets/images/app_bg.png'),
      showCharacter: false,
      showBrandText: false,
      showDecorations: false,
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
            focusNode: _emailFocusNode,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _passwordFocusNode.requestFocus(),
            clearable: true,
            errorText: _emailError,
            pill: true,
            onChanged: (_) {
              if (_emailError != null) {
                setState(() => _emailError = null);
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          ImoTextField(
            label: '비밀번호',
            hint: '비밀번호를 입력해주세요.',
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              _passwordFocusNode.unfocus();
              _submit();
            },
            obscureText: true,
            errorText: _passwordError,
            pill: true,
            onChanged: (_) {
              if (_passwordError != null) {
                setState(() => _passwordError = null);
              }
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          ImoButton(
            label: '로그인',
            loading: _submitting,
            disabled: _submitting,
            pill: true,
            onPressed: _submitting ? null : _submit,
          ),
          if (kDebugMode && isUsingCustomBackendApi) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.go('/chat'),
                child: const Text('로컬 챗 테스트로 바로 들어가기'),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'debug backend: $backendApiBaseUrl',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => context.push('/signup'),
                child: Text(
                  '회원가입',
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
                  '이전',
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
