import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/layouts/app_scaffold.dart';
import '../../core/widgets/common_widgets.dart';

class ExerciseSelectScreen extends StatelessWidget {
  const ExerciseSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Workout Setup',
      child: Center(
        child: ImoButton(
          label: 'Open workout',
          onPressed: () => context.go('/workout'),
        ),
      ),
    );
  }
}
