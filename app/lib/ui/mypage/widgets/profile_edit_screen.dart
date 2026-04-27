import 'package:flutter/material.dart';

import '../../core/layouts/app_scaffold.dart';

class ProfileEditScreen extends StatelessWidget {
  const ProfileEditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Edit Profile',
      child: Center(child: Text('Edit profile')),
    );
  }
}
