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
                const Center(child: _Logo()),
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
                StaggeredItem(
                  index: 3,
                  child: _AnimatedGlassCard(
                    context: context,
                    child: const FeatureRow(
                      icon: Icons.lock_outline_rounded,
                      title: 'Privacy-first',
                      subtitle: 'Find skills nearby without sharing your address.',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                StaggeredItem(
                  index: 4,
                  child: _AnimatedGlassCard(
                    context: context,
                    child: const FeatureRow(
                      icon: Icons.volunteer_activism_outlined,
                      title: 'Mutual aid',
                      subtitle: 'Offer what you know, get help when you need it.',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                StaggeredItem(
                  index: 5,
                  child: _AnimatedGlassCard(
                    context: context,
                    child: const FeatureRow(
                      icon: Icons.favorite_outline_rounded,
                      title: 'Gratitude, not payment',
                      subtitle: 'Optional tips to say thank you — never required.',
                    ),
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

class _AnimatedGlassCard extends StatefulWidget {
  const _AnimatedGlassCard({required this.context, required this.child});

  final BuildContext context;
  final Widget child;

  @override
  State<_AnimatedGlassCard> createState() => _AnimatedGlassCardState();
}

class _AnimatedGlassCardState extends State<_AnimatedGlassCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );

    _slide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

    return ScaleTransition(
      scale: _scale,
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(
          position: _slide,
          child: ClipRRect(
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
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatefulWidget {
  const _Logo();

  @override
  State<_Logo> createState() => _LogoState();
}

class _LogoState extends State<_Logo> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  late final Animation<double> _rotation;
  late final Animation<double> _sparkScale;

  static const _blobRadius = BorderRadius.only(
    topLeft: Radius.circular(48),
    topRight: Radius.circular(16),
    bottomLeft: Radius.circular(26),
    bottomRight: Radius.circular(58),
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.4, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 30,
      ),
    ]).animate(_controller);

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );

    _rotation = Tween<double>(begin: -0.35, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    // The gold spark pops in after the blob lands
    _sparkScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 0.95, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return FadeTransition(
          opacity: _opacity,
          child: Transform.rotate(
            angle: _rotation.value,
            child: Transform.scale(
              scale: _scale.value,
              child: SizedBox(
                width: 116,
                height: 116,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Main blob: warm gradient + layered shadows
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.terracotta, AppColors.terracottaDeep],
                        ),
                        borderRadius: _blobRadius,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.terracottaDeep.withValues(alpha: 0.35),
                            blurRadius: 32,
                            spreadRadius: -8,
                            offset: const Offset(0, 16),
                          ),
                          BoxShadow(
                            color: AppColors.ink.withValues(alpha: 0.10),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: _blobRadius,
                        child: Stack(
                          children: [
                            // Soft light source from the top-left
                            Positioned(
                              top: -30,
                              left: -30,
                              child: Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0.28),
                                      Colors.white.withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Center(
                              child: Icon(
                                Icons.handshake_rounded,
                                size: 50,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}