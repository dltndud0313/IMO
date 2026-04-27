import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/layouts/app_scaffold.dart';
import '../../core/widgets/common_widgets.dart';

class SessionResultScreen extends StatelessWidget {
  const SessionResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Session Result',
      child: Center(
        child: ImoButton(
          label: 'Back home',
          onPressed: () => context.go('/home'),
        ),
      ),
    );
  }
}
