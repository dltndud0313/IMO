import 'package:flutter/material.dart';

import '../../core/layouts/app_scaffold.dart';

class HistoryDetailScreen extends StatelessWidget {
  const HistoryDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'History Detail',
      child: Center(child: Text('History detail')),
    );
  }
}
