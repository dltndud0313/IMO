import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/layouts/app_scaffold.dart';
import '../../core/widgets/common_widgets.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Onboarding',
      child: Center(
        child: ImoButton(
          label: 'Go home',
          onPressed: () => context.go('/home'),
        ),
      ),
    );
  }
}
