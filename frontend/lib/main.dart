import 'package:flutter/material.dart';
import 'package:handover/screens/home_shell.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'screens/intro_page.dart';
import 'services/api.dart';
import 'services/revenuecat_service.dart';
import 'services/theme_controller.dart';
import 'theme/app_theme.dart';

const _oneSignalAppId = String.fromEnvironment(
  'ONESIGNAL_APP_ID',
  defaultValue: '',
);

Future<void> _registerPlayerId() async {
  final id = OneSignal.User.pushSubscription.id;
  if (id == null || !Api.hasToken) return;
  try {
    await Api.post('/api/onesignal/register', body: {'player_id': id});
  } catch (_) {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_oneSignalAppId.isNotEmpty) {
    try {
      OneSignal.initialize(_oneSignalAppId);
      OneSignal.Notifications.requestPermission(true);
      OneSignal.User.pushSubscription.addObserver((event) {
        if (event.current.id != null) _registerPlayerId();
      });
    } catch (_) {}
  }

  await Api.bootstrap();
await ThemeController.instance.bootstrap();

  await RevenueCatService.init();
  if (Api.hasToken) {
    final uid = Api.currentUserId;
    if (uid != null) await RevenueCatService.setUserId(uid.toString());
  }

  if (_oneSignalAppId.isNotEmpty) {
    await _registerPlayerId();
  }

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
