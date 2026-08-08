import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme/colors.dart';
import '../widgets/feature_row.dart';
import 'home_shell.dart';
import 'login_page.dart';

class IntroPage extends StatelessWidget {
  const IntroPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
          child: Column(
            children: [
              const Spacer(flex: 3),
              Container(
                width: 88,
                height: 88,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.terracotta,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.terracotta.withValues(alpha: 0.28),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: const Icon(Icons.handshake_rounded, size: 42, color: Colors.white),
              ),
              const SizedBox(height: 26),
              Text(
                'Handover',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Neighbors helping neighbors,\nskill by skill.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: AppColors.inkSoft, height: 1.4),
              ),
              const Spacer(flex: 3),
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FeatureRow(
                      icon: Icons.lock_outline_rounded,
                      title: 'Privacy-first',
                      subtitle: 'Find skills nearby without sharing your address.',
                      tint: AppColors.terracottaTint,
                    ),
                    FeatureRow(
                      icon: Icons.volunteer_activism_outlined,
                      title: 'Mutual aid',
                      subtitle: 'Offer what you know, get help when you need it.',
                      tint: AppColors.terracottaLight,
                    ),
                    FeatureRow(
                      icon: Icons.favorite_outline_rounded,
                      title: 'Gratitude, not payment',
                      subtitle: 'Optional tips to say thank you — never required.',
                      tint: AppColors.goldTint,
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 4),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage(initialMode: AuthMode.signUp)),
                  ),
                  child: const Text('Get started'),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () {
                  if (Api.hasToken) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const HomeShell()),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  }
                },
                child: const Text('I already have an account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}