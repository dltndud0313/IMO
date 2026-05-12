import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config/dependencies.dart';
import 'config/router.dart';
import 'config/theme.dart';

void _registerLicenses() {
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString(
      'assets/licenses/react_native_body_highlighter_MIT.txt',
    );
    yield LicenseEntryWithLineBreaks(
      ['react-native-body-highlighter (SVG body paths)'],
      license,
    );
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerLicenses();
  await setupDependencies();
  runApp(const ImoApp());
}

class ImoApp extends StatelessWidget {
  const ImoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'IMO',
      theme: buildAppTheme(),
      darkTheme: buildDarkAppTheme(),
      themeMode: ThemeMode.light,
      routerConfig: buildRouter(),
      debugShowCheckedModeBanner: false,
    );
  }
}
