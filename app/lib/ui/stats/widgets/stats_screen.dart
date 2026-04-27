import 'package:flutter/material.dart';

import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Stats',
      child: Text('Weekly stats', style: AppTextStyles.title),
    );
  }
}
