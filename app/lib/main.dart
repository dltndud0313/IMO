import 'package:flutter/material.dart';

import 'config/app_settings.dart';
import 'config/dependencies.dart';
import 'config/router.dart';
import 'config/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupDependencies();
  runApp(const ImoApp());
}

class ImoApp extends StatelessWidget {
  const ImoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, themeMode, _) {
        return MaterialApp.router(
          title: 'IMO',
          theme: buildAppTheme(),
          darkTheme: buildDarkAppTheme(),
          themeMode: themeMode,
          routerConfig: buildRouter(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
