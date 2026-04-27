import 'package:flutter/material.dart';

import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';

class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'My Page',
      child: Text('Profile and settings', style: AppTextStyles.title),
    );
  }
}
