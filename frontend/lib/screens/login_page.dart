import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api.dart';
import '../theme/colors.dart';
import '../widgets/staggered_entrance.dart';
import 'home_shell.dart';
import 'legal_page.dart';

enum AuthMode { signIn, signUp }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.initialMode = AuthMode.signIn});

  final AuthMode initialMode;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late AuthMode _mode = widget.initialMode;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _loading = false;
  bool _acceptedConsent = false;

  static const _crossFadeDuration = Duration(milliseconds: 280);

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  void _snack(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    final name = _name.text.trim();
    if (email.isEmpty ||
        password.isEmpty ||
        (_mode == AuthMode.signUp && name.isEmpty)) {
      _snack(
        _mode == AuthMode.signUp
            ? 'Name, email and password required'
            : 'Email and password required',
      );
      return;
    }
    if (_mode == AuthMode.signUp && !_acceptedConsent) {
      _snack('Please accept the Terms of Service and Privacy Policy to continue.');
      return;
    }
    setState(() => _loading = true);
    try {
      final body = _mode == AuthMode.signUp
          ? {
              'email': email,
              'password': password,
              'name': name,
              'lat': Api.demoLat,
              'lng': Api.demoLng,
              'accept_tos': true,
              'accept_privacy': true,
            }
          : {'email': email, 'password': password};
      final res = await Api.post(
        _mode == AuthMode.signUp ? '/api/auth/signup' : '/api/auth/login',
        body: body,
      );
      final user =
          (res as Map<String, dynamic>)['user'] as Map<String, dynamic>;
      await Api.storeSession(res['token'] as String, user['id'] as int);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(describeError(e));
    }
  }

  void _toggleMode() {
    HapticFeedback.selectionClick();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _mode = _mode == AuthMode.signIn ? AuthMode.signUp : AuthMode.signIn;
      _acceptedConsent = false;
    });
  }

  void _openLegal(LegalDocument document) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LegalPage(document: document)),
    );
  }

  Widget _crossFade(Widget child) {
    return AnimatedSwitcher(
      duration: _crossFadeDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSignup = _mode == AuthMode.signUp;

    final backButtonBg = isDark
        ? AppColors.darkSand.withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.7);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: StaggeredEntrance(
          duration: const Duration(milliseconds: 1100),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
            children: [
              StaggeredItem(
                index: 0,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: theme.colorScheme.onSurface,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: backButtonBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              StaggeredItem(
                index: 1,
                child: _crossFade(
                  Text(
                    isSignup ? 'Create your account' : 'Welcome back',
                    key: ValueKey('title-$_mode'),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      letterSpacing: -0.6,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              StaggeredItem(
                index: 2,
                child: _crossFade(
                  Text(
                    isSignup
                        ? 'Offer a skill, and neighbors nearby will find you.'
                        : 'Sign in to see who nearby can lend a hand.',
                    key: ValueKey('subtitle-$_mode'),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.65,
                      ),
                      fontSize: 14.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              _AnimatedNameField(
                show: isSignup,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel(label: 'Name'),
                    const SizedBox(height: 8),
                    _GlassField(
                      controller: _name,
                      hintText: 'Jane Doe',
                      icon: Icons.badge_outlined,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),

              StaggeredItem(index: 3, child: _FieldLabel(label: 'Email')),
              const SizedBox(height: 8),
              StaggeredItem(
                index: 3,
                child: _GlassField(
                  controller: _email,
                  hintText: 'you@example.com',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
              const SizedBox(height: 18),
              StaggeredItem(index: 4, child: _FieldLabel(label: 'Password')),
              const SizedBox(height: 8),
              StaggeredItem(
                index: 4,
                child: _GlassField(
                  controller: _password,
                  hintText: '••••••••',
                  icon: Icons.lock_outline_rounded,
                  isPassword: true,
                ),
              ),
              const SizedBox(height: 18),
              _AnimatedConsentRow(
                show: isSignup,
                accepted: _acceptedConsent,
                onChanged: (value) => setState(() => _acceptedConsent = value),
                onOpenTerms: () => _openLegal(LegalDocument.terms),
                onOpenPrivacy: () => _openLegal(LegalDocument.privacy),
              ),
              const SizedBox(height: 18),
              StaggeredItem(
                index: 5,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.terracotta,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                      elevation: 0,
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : _crossFade(
                            Text(
                              isSignup ? 'Create account' : 'Sign in',
                              key: ValueKey('btn-$_mode'),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              StaggeredItem(
                index: 6,
                child: TextButton(
                  onPressed: _loading ? null : _toggleMode,
                  child: _crossFade(
                    Text(
                      isSignup
                          ? 'I already have an account, sign in'
                          : 'New here? Create an account',
                      key: ValueKey('toggle-$_mode'),
                      style: TextStyle(
                        color: isDark
                            ? AppColors.terracotta
                            : AppColors.terracottaDeep,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        letterSpacing: 0.1,
      ),
    );
  }
}

class _AnimatedNameField extends StatefulWidget {
  const _AnimatedNameField({required this.show, required this.child});

  final bool show;
  final Widget child;

  @override
  State<_AnimatedNameField> createState() => _AnimatedNameFieldState();
}

class _AnimatedNameFieldState extends State<_AnimatedNameField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _size;
  late final CurvedAnimation _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
      value: widget.show ? 1.0 : 0.0,
    );
    _size = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
  }

  @override
  void didUpdateWidget(covariant _AnimatedNameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show != oldWidget.show) {
      if (widget.show) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _size.dispose();
    _fade.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _size,
      alignment: const Alignment(-1.0, -1.0),
      child: IgnorePointer(
        ignoring: !widget.show,
        child: ExcludeSemantics(
          excluding: !widget.show,
          child: FadeTransition(opacity: _fade, child: widget.child),
        ),
      ),
    );
  }
}

class _GlassField extends StatefulWidget {
  const _GlassField({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.isPassword = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool isPassword;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  @override
  State<_GlassField> createState() => _GlassFieldState();
}

class _GlassFieldState extends State<_GlassField> {
  late bool _obscureText = widget.isPassword;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark
        ? AppColors.darkSand.withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.72);

    final borderColor = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.7)
        : Colors.white.withValues(alpha: 0.9);

    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.2)
        : AppColors.inkSoft.withValues(alpha: 0.04);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: widget.controller,
        obscureText: _obscureText,
        keyboardType: widget.keyboardType,
        textCapitalization: widget.textCapitalization,
        style: TextStyle(
          fontSize: 14.5,
          color: theme.colorScheme.onSurface,
          height: 1.2,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            fontSize: 14.5,
          ),

          prefixIconConstraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
          ),

          prefixIcon: Icon(
            widget.icon,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            size: 20,
          ),

          suffixIcon: widget.isPassword
              ? IconButton(
                  icon: Icon(
                    _obscureText
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureText = !_obscureText;
                    });
                  },
                )
              : null,

          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _AnimatedConsentRow extends StatefulWidget {
  const _AnimatedConsentRow({
    required this.show,
    required this.accepted,
    required this.onChanged,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  final bool show;
  final bool accepted;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  @override
  State<_AnimatedConsentRow> createState() => _AnimatedConsentRowState();
}

class _AnimatedConsentRowState extends State<_AnimatedConsentRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _size;
  late final CurvedAnimation _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
      value: widget.show ? 1.0 : 0.0,
    );
    _size = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
  }

  @override
  void didUpdateWidget(covariant _AnimatedConsentRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show != oldWidget.show) {
      if (widget.show) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _size.dispose();
    _fade.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final consentColor = isDark ? AppColors.terracotta : AppColors.terracottaDeep;

    return SizeTransition(
      sizeFactor: _size,
      alignment: const Alignment(-1.0, -1.0),
      child: IgnorePointer(
        ignoring: !widget.show,
        child: ExcludeSemantics(
          excluding: !widget.show,
          child: FadeTransition(
            opacity: _fade,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSand.withValues(alpha: 0.5)
                    : AppColors.sand.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.onChanged(!widget.accepted);
                    },
                    child: Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(top: 1),
                      decoration: BoxDecoration(
                        color: widget.accepted
                            ? AppColors.sage
                            : (isDark
                                  ? AppColors.darkSand
                                  : Colors.white),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: widget.accepted
                              ? AppColors.sage
                              : theme.colorScheme.onSurface.withValues(alpha: 0.25),
                          width: 1.4,
                        ),
                      ),
                      child: widget.accepted
                          ? const Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.75,
                          ),
                        ),
                        children: [
                          const TextSpan(
                            text: 'I\'m at least 16 and I agree to the ',
                          ),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.baseline,
                            baseline: TextBaseline.alphabetic,
                            child: GestureDetector(
                              onTap: widget.onOpenTerms,
                              child: Text(
                                'Terms of Service',
                                style: TextStyle(
                                  color: consentColor,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                  decorationColor: consentColor.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const TextSpan(text: ' and '),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.baseline,
                            baseline: TextBaseline.alphabetic,
                            child: GestureDetector(
                              onTap: widget.onOpenPrivacy,
                              child: Text(
                                'Privacy Policy',
                                style: TextStyle(
                                  color: consentColor,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                  decorationColor: consentColor.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const TextSpan(
                            text: '. Your data is never sold and stays in the EU.',
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
      ),
    );
  }
}
