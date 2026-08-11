import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api.dart';
import '../theme/colors.dart';
import '../widgets/feature_row.dart';
import '../widgets/staggered_entrance.dart';
import 'home_shell.dart';
import 'login_page.dart';

class IntroPage extends StatelessWidget {
  const IntroPage({super.key});

  Route<T> _fadeSlideRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 500),
      reverseTransitionDuration: const Duration(milliseconds: 350),
      opaque: false,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fade = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        return FadeTransition(opacity: fade, child: SlideTransition(position: slide, child: child));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: StaggeredEntrance(
          duration: const Duration(milliseconds: 1400),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
            child: Column(
              children: [
                const Spacer(flex: 3),
                const Center(child: _BreathingLogo()),
                const SizedBox(height: 32),
                StaggeredItem(
                  index: 1,
                  child: Text(
                    'Handover',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      letterSpacing: -0.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                StaggeredItem(
                  index: 2,
                  child: Text(
                    'Neighbors helping neighbors,\nskill by skill.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      height: 1.5,
                      letterSpacing: 0.1,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const Spacer(flex: 8),
                _glassCard(
                  context: context,
                  child: const FeatureRow(
                    icon: Icons.lock_outline_rounded,
                    title: 'Privacy-first',
                    subtitle: 'Find skills nearby without sharing your address.',
                  ),
                ),
                const SizedBox(height: 12),
                _glassCard(
                  context: context,
                  child: const FeatureRow(
                    icon: Icons.volunteer_activism_outlined,
                    title: 'Mutual aid',
                    subtitle: 'Offer what you know, get help when you need it.',
                  ),
                ),
                const SizedBox(height: 12),
                _glassCard(
                  context: context,
                  child: const FeatureRow(
                    icon: Icons.favorite_outline_rounded,
                    title: 'Gratitude, not payment',
                    subtitle: 'Optional tips to say thank you — never required.',
                  ),
                ),
                const Spacer(flex: 8),
                StaggeredItem(
                  index: 6,
                  child: _buildTactileButton(
                    context,
                    'Get started',
                    isPrimary: true,
                    onPressed: () => Navigator.push(
                      context,
                      _fadeSlideRoute(const LoginPage(initialMode: AuthMode.signUp)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                StaggeredItem(
                  index: 7,
                  child: _buildTactileButton(
                    context,
                    'I already have an account',
                    isPrimary: false,
                    onPressed: () {
                      if (Api.hasToken) {
                        Navigator.of(context).pushReplacement(
                          _fadeSlideRoute(const HomeShell()),
                        );
                      } else {
                        Navigator.push(
                          context,
                          _fadeSlideRoute(const LoginPage()),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassCard({required BuildContext context, required Widget child}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final glassColor = isDark
        ? AppColors.darkPaper.withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.65);

    final glassBorder = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.8);

    final glassShadow = isDark
        ? Colors.black.withValues(alpha: 0.25)
        : AppColors.inkSoft.withValues(alpha: 0.04);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: glassColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: glassBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: glassShadow,
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: child,
        ),
      ),
    );
  }

  Widget _buildTactileButton(
    BuildContext context,
    String text, {
    bool isPrimary = false,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final secondaryBorderColor = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.6)
        : AppColors.inkSoft.withValues(alpha: 0.12);

    final secondaryTextColor = theme.colorScheme.onSurface.withValues(alpha: 0.7);

    return Material(
      color: isPrimary ? AppColors.terracotta : Colors.transparent,
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
        borderRadius: BorderRadius.circular(100),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            border: isPrimary ? null : Border.all(color: secondaryBorderColor, width: 1.5),
            boxShadow: isPrimary
                ? [
                    BoxShadow(
                      color: AppColors.terracotta.withValues(alpha: isDark ? 0.35 : 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w500,
                color: isPrimary ? Colors.white : secondaryTextColor,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BreathingLogo extends StatelessWidget {
  const _BreathingLogo();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 4500),
      curve: Curves.easeInOutSine,
      builder: (context, t, child) {
        final scale = 1.0 + (0.04 * (0.5 - (t - 0.5).abs()));
        final rotation = 0.015 * (0.5 - (t - 0.5).abs());

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..scale(scale)
            ..rotateZ(rotation),
          child: Container(
            width: 110,
            height: 110,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.terracotta,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(45),
                topRight: Radius.circular(15),
                bottomLeft: Radius.circular(25),
                bottomRight: Radius.circular(55),
              ),
            ),
            child: const Icon(Icons.handshake_rounded, size: 48, color: Colors.white),
          ),
        );
      },
    );
  }
}