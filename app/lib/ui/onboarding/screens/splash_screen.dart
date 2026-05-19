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
      backgroundImage: const AssetImage('assets/images/app_bg.png'),
      showCharacter: false,
      showBrandText: false,
      logoImage: 'assets/images/app_imo3.png',
      logoSize: 180,
      showDecorations: false,
      topContentAlignment: const Alignment(0, 0.2),
      sheet: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ImoButton(
            label: '로그인',
            pill: true,
            onPressed: () => context.go('/login'),
          ),
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
