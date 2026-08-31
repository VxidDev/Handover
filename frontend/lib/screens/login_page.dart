import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api.dart';
import '../theme/colors.dart';
import '../widgets/staggered_entrance.dart';
import 'forgot_password_page.dart';
import 'home_shell.dart';
import 'legal_page.dart';
import 'onboarding_page.dart';

enum AuthMode { signIn, signUp }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.initialMode = AuthMode.signIn});

  final AuthMode initialMode;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late AuthMode _mode;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _scrollController = ScrollController();

  bool _loading = false;
  bool _acceptedConsent = false;

  static const _crossFadeDuration = Duration(milliseconds: 280);

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _snack(String message, {bool isError = true}) {
    if (!mounted) return;
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
    FocusManager.instance.primaryFocus?.unfocus();
    
    final email = _email.text.trim();
    final password = _password.text;
    final name = _name.text.trim();

    if (email.isEmpty || password.isEmpty || (_mode == AuthMode.signUp && name.isEmpty)) {
      _snack(
        _mode == AuthMode.signUp
            ? 'Name, email, and password are required'
            : 'Email and password are required',
      );
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _snack('Please enter a valid email address');
      return;
    }
    if (password.length < 6) {
      _snack('Password must be at least 6 characters');
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
              'accept_tos': true,
              'accept_privacy': true,
            }
          : {'email': email, 'password': password};
          
      final res = await Api.post(
        _mode == AuthMode.signUp ? '/api/auth/signup' : '/api/auth/login',
        body: body,
      );
      
      final user = (res as Map<String, dynamic>)['user'] as Map<String, dynamic>;
      await Api.storeSession(
        res['token'] as String,
        user['id'] as int,
        lat: (user['lat'] as num?)?.toDouble(),
        lng: (user['lng'] as num?)?.toDouble(),
      );
      
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => _mode == AuthMode.signUp
              ? const OnboardingPage()
              : const HomeShell(),
        ),
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
    
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
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
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
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

    final forgotPasswordColor = isDark ? AppColors.terracotta : AppColors.terracottaDeep;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: StaggeredEntrance(
          duration: const Duration(milliseconds: 1100),
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 48),
            physics: const BouncingScrollPhysics(),
            children: [
              StaggeredItem(
                index: 0,
                child: IconButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).maybePop();
                  },
                  icon: Icon(Icons.arrow_back_rounded, color: theme.colorScheme.onSurface),
                  style: IconButton.styleFrom(
                    backgroundColor: backButtonBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      fontSize: 14.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              StaggeredItem(
                index: 3,
                child: _AnimatedNameField(
                  show: isSignup,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel(label: 'Name'),
                      const SizedBox(height: 8),
                      _GlassField(
                        controller: _name,
                        focusNode: _nameFocus,
                        hintText: 'Jane Doe',
                        icon: Icons.badge_outlined,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _emailFocus.requestFocus(),
                        autofillHints: const [AutofillHints.name],
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),

              AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StaggeredItem(index: 4, child: _FieldLabel(label: 'Email')),
                    const SizedBox(height: 8),
                    StaggeredItem(
                      index: 5,
                      child: _GlassField(
                        controller: _email,
                        focusNode: _emailFocus,
                        hintText: 'you@example.com',
                        icon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _passwordFocus.requestFocus(),
                        autofillHints: const [AutofillHints.email],
                      ),
                    ),
                    const SizedBox(height: 18),
                    StaggeredItem(index: 6, child: _FieldLabel(label: 'Password')),
                    const SizedBox(height: 8),
                    StaggeredItem(
                      index: 7,
                      child: _GlassField(
                        controller: _password,
                        focusNode: _passwordFocus,
                        hintText: '••••••••',
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        autofillHints: [isSignup ? AutofillHints.newPassword : AutofillHints.password],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 18),
              
              StaggeredItem(
                index: 8,
                child: _AnimatedConsentRow(
                  show: isSignup,
                  accepted: _acceptedConsent,
                  onChanged: (value) => setState(() => _acceptedConsent = value),
                  onOpenTerms: () => _openLegal(LegalDocument.terms),
                  onOpenPrivacy: () => _openLegal(LegalDocument.privacy),
                ),
              ),
              
              const SizedBox(height: 18),
              
              StaggeredItem(
                index: 9,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.terracotta,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
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
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
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
              
              // Toggle button (Sign in / Create account)
              StaggeredItem(
                index: 10,
                child: Semantics(
                  button: true,
                  label: isSignup ? 'I already have an account, sign in' : 'New here? Create an account',
                  child: TextButton(
                    onPressed: _loading ? null : _toggleMode,
                    child: _crossFade(
                      Text(
                        isSignup
                            ? 'I already have an account, sign in'
                            : 'New here? Create an account',
                        key: ValueKey('toggle-$_mode'),
                        style: TextStyle(
                          color: isDark ? AppColors.terracotta : AppColors.terracottaDeep,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Forgot password moved to the very bottom, only visible in signIn mode
              if (!isSignup) ...[
                const SizedBox(height: 4),
                StaggeredItem(
                  index: 11,
                  child: Center(
                    child: TextButton(
                      onPressed: _loading
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                              );
                            },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        tapTargetSize: MaterialTapTargetSize.padded,
                      ),
                      child: Text(
                        'Forgot password?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: forgotPasswordColor,
                          decoration: TextDecoration.underline,
                          decorationColor: forgotPasswordColor.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool isPassword;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;

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
        focusNode: widget.focusNode,
        obscureText: _obscureText,
        keyboardType: widget.keyboardType,
        textCapitalization: widget.textCapitalization,
        textInputAction: widget.textInputAction,
        onSubmitted: widget.onSubmitted,
        autofillHints: widget.autofillHints,
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
          prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          suffixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          prefixIcon: Icon(
            widget.icon,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            size: 20,
          ),
          suffixIcon: widget.isPassword
              ? IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                )
              : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                  Semantics(
                    toggled: widget.accepted,
                    label: 'Accept terms of service and privacy policy',
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onChanged(!widget.accepted);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(13),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          width: 22,
                          height: 22,
                          margin: const EdgeInsets.only(top: 1),
                          decoration: BoxDecoration(
                            color: widget.accepted
                                ? AppColors.sage
                                : (isDark ? AppColors.darkSand : Colors.white),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: widget.accepted
                                  ? AppColors.sage
                                  : theme.colorScheme.onSurface.withValues(alpha: 0.25),
                              width: 1.4,
                            ),
                          ),
                          child: widget.accepted
                              ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                        ),
                        children: [
                          const TextSpan(text: 'I\'m at least 16 and I agree to the '),
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
                                  decorationColor: consentColor.withValues(alpha: 0.5),
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
                                  decorationColor: consentColor.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          ),
                          const TextSpan(text: '. Your data is never sold and stays in the EU.'),
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