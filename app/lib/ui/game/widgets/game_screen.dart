import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';
import '../view_model/game_viewmodel.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '게임하기',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.go('/home'),
      body: Consumer<GameViewModel>(
        builder: (context, viewModel, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ImoCard(
                paddingSize: ImoCardPadding.lg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('게임 모드', style: AppTextStyles.title),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '센서 연결 상태: ${viewModel.isConnected ? "연결됨" : "미연결"}',
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      '게임 기능은 준비 중입니다.\n곧 만나보실 수 있어요!',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
