import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api.dart';
import '../theme/colors.dart';
import '../widgets/feature_row.dart';
import 'home_shell.dart';
import 'login_page.dart';

class IntroPage extends StatefulWidget {
  const IntroPage({super.key});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _subtitleSlide;
  late final Animation<double> _subtitleFade;
  late final Animation<double> _buttonsFade;
  late final Animation<Offset> _buttonsSlide;

  Animation<double> _fadeFor(double start, double end, {Curve curve = Curves.easeOutExpo}) =>
      CurvedAnimation(parent: _controller, curve: Interval(start, end, curve: curve));

  Animation<Offset> _slideFor(double start, double end, {double dy = 0.15}) =>
      Tween<Offset>(begin: Offset(0, dy), end: Offset.zero).animate(
        CurvedAnimation(parent: _controller, curve: Interval(start, end, curve: Curves.easeOutExpo)),
      );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack)),
    );
    _logoFade = _fadeFor(0.0, 0.4);

    _titleFade = _fadeFor(0.15, 0.5);
    _titleSlide = _slideFor(0.15, 0.5);

    _subtitleFade = _fadeFor(0.25, 0.6);
    _subtitleSlide = _slideFor(0.25, 0.6);

    _buttonsFade = _fadeFor(0.65, 1.0);
    _buttonsSlide = _slideFor(0.65, 1.0, dy: 0.08);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _glassCard({required int index, required Widget child}) {
    final start = 0.35 + (index * 0.08);
    final end = (start + 0.35).clamp(0.0, 1.0);

    return FadeTransition(
      opacity: _fadeFor(start, end),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
          CurvedAnimation(parent: _controller, curve: Interval(start, end, curve: Curves.easeOutExpo)),
        ),
        child: Transform.translate(
          offset: Offset(0, index * -14.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.65), // Frosted base
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.inkSoft.withOpacity(0.04),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTactileButton(BuildContext context, String text, {bool isPrimary = false, required VoidCallback onPressed}) {
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
            border: isPrimary ? null : Border.all(color: AppColors.inkSoft.withOpacity(0.12), width: 1.5),
            boxShadow: isPrimary
                ? [
                    BoxShadow(
                      color: AppColors.terracotta.withOpacity(0.25),
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
                color: isPrimary ? Colors.white : AppColors.inkSoft,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBreathingLogo() {
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
            decoration: BoxDecoration(
              color: AppColors.terracotta,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(45),
                topRight: Radius.circular(15),
                bottomLeft: Radius.circular(25),
                bottomRight: Radius.circular(55),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.terracotta.withOpacity(0.25),
                  blurRadius: 40,
                  spreadRadius: -10,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: const Icon(Icons.handshake_rounded, size: 48, color: Colors.white),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        children: [
          Positioned(
            top: -50, right: -50,
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [AppColors.goldTint.withOpacity(0.3), Colors.transparent]),
              ),
            ),
          ),
          Positioned(
            bottom: 100, left: -50,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [AppColors.terracottaTint.withOpacity(0.2), Colors.transparent]),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  _buildBreathingLogo(),
                  const SizedBox(height: 28),
                  SlideTransition(
                    position: _titleSlide,
                    child: FadeTransition(
                      opacity: _titleFade,
                      child: Text(
                        'Handover',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          letterSpacing: -0.8,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SlideTransition(
                    position: _subtitleSlide,
                    child: FadeTransition(
                      opacity: _subtitleFade,
                      child: Text(
                        'Neighbors helping neighbors,\nskill by skill.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.inkSoft.withOpacity(0.75),
                          height: 1.5, // Breathing room for warmth
                          letterSpacing: 0.1,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 64),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _glassCard(
                          index: 0,
                          child: FeatureRow(
                            icon: Icons.lock_outline_rounded,
                            title: 'Privacy-first',
                            subtitle: 'Find skills nearby without sharing your address.',
                            tint: AppColors.terracottaTint,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _glassCard(
                          index: 1,
                          child: FeatureRow(
                            icon: Icons.volunteer_activism_outlined,
                            title: 'Mutual aid',
                            subtitle: 'Offer what you know, get help when you need it.',
                            tint: AppColors.terracottaLight,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _glassCard(
                          index: 2,
                          child: FeatureRow(
                            icon: Icons.favorite_outline_rounded,
                            title: 'Gratitude, not payment',
                            subtitle: 'Optional tips to say thank you — never required.',
                            tint: AppColors.goldTint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 4),
                  SlideTransition(
                    position: _buttonsSlide,
                    child: FadeTransition(
                      opacity: _buttonsFade,
                      child: Column(
                        children: [
                          _buildTactileButton(
                            context,
                            'Get started',
                            isPrimary: true,
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginPage(initialMode: AuthMode.signUp)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildTactileButton(
                            context,
                            'I already have an account',
                            isPrimary: false,
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
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}