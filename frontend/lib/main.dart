import 'package:flutter/material.dart';
import 'package:handover/screens/home_shell.dart';
import 'screens/intro_page.dart';
import 'services/api.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.bootstrap();
  runApp(const HandoverApp());
}

class HandoverApp extends StatelessWidget {
  const HandoverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Handover',
      debugShowCheckedModeBanner: false,
      darkTheme: AppTheme.dark,
      theme: AppTheme.light,
      themeMode: ThemeMode.system,
      home: Api.hasToken ? const HomeShell() : const IntroPage(),
    );
  }
}
