import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';
import '../view_model/home_viewmodel.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HomeViewModel>();

    return AppScaffold(
      title: 'IMO',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Home', style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.sm),
          Text(viewModel.statusLabel, style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.lg),
          ImoButton(
            label: 'Start workout setup',
            icon: Icons.fitness_center,
            onPressed: () => context.go('/workout-setup'),
          ),
        ],
      ),
    );
  }
}
