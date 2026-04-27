import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/layouts/app_scaffold.dart';
import '../../core/widgets/common_widgets.dart';

class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Workout',
      child: Center(
        child: ImoButton(
          label: 'Finish workout',
          onPressed: () => context.go('/session-result'),
        ),
      ),
    );
  }
}
