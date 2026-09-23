import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api.dart';
import '../theme/colors.dart';
import '../widgets/staggered_entrance.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _email = TextEditingController();
  final _emailCode = TextEditingController();
  final _totpCode = TextEditingController();
  final _newPassword = TextEditingController();
  final _recoveryCode = TextEditingController();

  bool _loading = false;
  int _step = 1;
  String _codeMode = 'email'; // 'email', 'totp', or 'recovery'

  @override
  void dispose() {
    _email.dispose();
    _emailCode.dispose();
    _totpCode.dispose();
    _newPassword.dispose();
    _recoveryCode.dispose();
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

  Future<void> _sendEmailCode() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      _snack('Please enter your email address');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _snack('Please enter a valid email address');
      return;
    }

    setState(() => _loading = true);
    try {
      await Api.post('/api/auth/forgot-password', body: {'email': email});
      if (!mounted) return;
      setState(() {
        _loading = false;
        _codeMode = 'email';
        _step = 2;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(describeError(e));
    }
  }

  void _use2FA() {
    final email = _email.text.trim();
    if (email.isEmpty) {
      _snack('Please enter your email address first');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _snack('Please enter a valid email address');
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _codeMode = 'totp';
      _step = 2;
    });
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    final password = _newPassword.text;

    if (password.length < 6) {
      _snack('Password must be at least 6 characters');
      return;
    }

    final body = <String, dynamic>{'email': email, 'new_password': password};

    if (_codeMode == 'email') {
      final code = _emailCode.text.trim();
      if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
        _snack('Please enter a valid 6-digit code');
        return;
      }
      body['email_code'] = code;
    } else if (_codeMode == 'recovery') {
      final code = _recoveryCode.text.trim();
      if (code.isEmpty) {
        _snack('Please enter a recovery code');
        return;
      }
      body['recovery_code'] = code;
    } else {
      final code = _totpCode.text.trim();
      if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
        _snack('Please enter a valid 6-digit code');
        return;
      }
      body['totp_code'] = code;
    }

    setState(() => _loading = true);
    try {
      await Api.post('/api/auth/reset-password', body: body);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _step = 3;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(describeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                child: Text(
                  'Reset your password',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    letterSpacing: -0.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              StaggeredItem(
                index: 2,
                child: Text(
                  _step == 1
                      ? 'Enter the email address you signed up with'
                      : _step == 2
                      ? _codeMode == 'email'
                            ? 'Enter the code sent to your email'
                            : _codeMode == 'recovery'
                            ? 'Enter a recovery code'
                            : 'Enter your authenticator code'
                      : 'Your password has been reset',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    fontSize: 14.5,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (_step == 1) ...[
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
                const SizedBox(height: 24),
                StaggeredItem(
                  index: 4,
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _sendEmailCode,
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
                          : const Text('Send code'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                StaggeredItem(
                  index: 5,
                  child: Center(
                    child: TextButton(
                      onPressed: _loading ? null : _use2FA,
                      child: Text(
                        'Have a 2FA code? Use it instead',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.terracotta
                              : AppColors.terracottaDeep,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ] else if (_step == 2) ...[
                if (_codeMode == 'email') ...[
                  StaggeredItem(
                    index: 3,
                    child: _FieldLabel(label: 'Email code'),
                  ),
                  const SizedBox(height: 8),
                  StaggeredItem(
                    index: 3,
                    child: _GlassField(
                      controller: _emailCode,
                      hintText: '000000',
                      icon: Icons.pin_outlined,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                    ),
                  ),
                ] else if (_codeMode == 'recovery') ...[
                  StaggeredItem(
                    index: 3,
                    child: _FieldLabel(label: 'Recovery code'),
                  ),
                  const SizedBox(height: 8),
                  StaggeredItem(
                    index: 3,
                    child: _GlassField(
                      controller: _recoveryCode,
                      hintText: 'Enter recovery code',
                      icon: Icons.vpn_key_outlined,
                    ),
                  ),
                ] else ...[
                  StaggeredItem(
                    index: 3,
                    child: _FieldLabel(label: 'Authenticator code'),
                  ),
                  const SizedBox(height: 8),
                  StaggeredItem(
                    index: 3,
                    child: _GlassField(
                      controller: _totpCode,
                      hintText: '000000',
                      icon: Icons.pin_outlined,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                StaggeredItem(
                  index: 4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_codeMode != 'email')
                        Flexible(
                          child: TextButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setState(() => _codeMode = 'email');
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: Text(
                              'Email code',
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.terracotta
                                    : AppColors.terracottaDeep,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      if (_codeMode != 'email' && _codeMode != 'totp')
                        Text(
                          'or',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                            fontSize: 12.5,
                          ),
                        ),
                      if (_codeMode != 'totp')
                        Flexible(
                          child: TextButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setState(() => _codeMode = 'totp');
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: Text(
                              'Authenticator code',
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.terracotta
                                    : AppColors.terracottaDeep,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      if (_codeMode != 'email' && _codeMode != 'recovery')
                        Text(
                          'or',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                            fontSize: 12.5,
                          ),
                        ),
                      if (_codeMode != 'recovery')
                        Flexible(
                          child: TextButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setState(() => _codeMode = 'recovery');
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: Text(
                              'Recovery code',
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.terracotta
                                    : AppColors.terracottaDeep,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                StaggeredItem(
                  index: 5,
                  child: _FieldLabel(label: 'New password'),
                ),
                const SizedBox(height: 8),
                StaggeredItem(
                  index: 5,
                  child: _GlassField(
                    controller: _newPassword,
                    hintText: '••••••••',
                    icon: Icons.lock_outline_rounded,
                    isPassword: true,
                  ),
                ),
                const SizedBox(height: 24),
                StaggeredItem(
                  index: 6,
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _resetPassword,
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
                          : const Text('Reset password'),
                    ),
                  ),
                ),
              ] else ...[
                StaggeredItem(
                  index: 3,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSand.withValues(alpha: 0.5)
                          : AppColors.sand.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.sage.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_outline_rounded,
                            color: AppColors.sage,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Password reset successfully. You can now sign in with your new password.',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                StaggeredItem(
                  index: 4,
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
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
                      child: const Text('Back to sign in'),
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

class _GlassField extends StatefulWidget {
  const _GlassField({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.keyboardType,
    this.isPassword = false,
    this.maxLength,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool isPassword;
  final int? maxLength;

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
        maxLength: widget.maxLength,
        style: TextStyle(
          fontSize: 14.5,
          color: theme.colorScheme.onSurface,
          height: 1.2,
          letterSpacing: widget.maxLength != null ? 4.0 : null,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            fontSize: 14.5,
          ),
          counterText: '',
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
                  onPressed: () => setState(() => _obscureText = !_obscureText),
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
