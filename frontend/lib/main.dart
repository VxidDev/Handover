import 'package:flutter/material.dart';
import 'package:handover/screens/home_shell.dart';
import 'screens/intro_page.dart';
import 'services/api.dart';
import 'services/theme_controller.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.bootstrap();
  await ThemeController.instance.bootstrap();
  runApp(const HandoverApp());
}

class HandoverApp extends StatelessWidget {
  const HandoverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Handover',
          debugShowCheckedModeBanner: false,
          darkTheme: AppTheme.dark,
          theme: AppTheme.light,
          themeMode: ThemeController.instance.mode,
          home: Api.hasToken ? const HomeShell() : const IntroPage(),
        );
      },
    );
  }
}
