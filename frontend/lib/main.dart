import 'package:flutter/material.dart';
import 'screens/intro_page.dart';
import 'theme/app_theme.dart';

void main() => runApp(const HandoverApp());

class HandoverApp extends StatelessWidget {
  const HandoverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Handover',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const IntroPage(),
    );
  }
}