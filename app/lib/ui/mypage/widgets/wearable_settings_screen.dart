import 'package:flutter/material.dart';

import '../../core/layouts/app_scaffold.dart';

class WearableSettingsScreen extends StatelessWidget {
  const WearableSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Wearable Settings',
      child: Center(child: Text('Wearable settings')),
    );
  }
}
