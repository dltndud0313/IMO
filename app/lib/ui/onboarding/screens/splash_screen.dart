import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../auth/widgets/auth_frame.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthFrame(
      backgroundImage: const AssetImage('assets/images/login.png'),
      showCharacter: true,
      characterImage: 'assets/images/mascot_default.png',
      characterSize: 400,
      showBrandText: false,
      showDecorations: true,
      sheet: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ImoButton(label: '로그인', onPressed: () => context.go('/login')),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: () => context.go('/onboarding'),
            child: Text(
              '가입없이 둘러보기',
              style: AppTextStyles.bodyLg.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
