import 'package:flutter/material.dart';

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
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
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
        _sent = true;
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
                  'Enter the email address you signed up with',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    fontSize: 14.5,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (_sent) ...[
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
                            Icons.mark_email_read_rounded,
                            color: AppColors.sage,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Check your email for a reset link',
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
              ] else ...[
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
                          : const Text('Send reset link'),
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
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;

  @override
  State<_GlassField> createState() => _GlassFieldState();
}

class _GlassFieldState extends State<_GlassField> {
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
        keyboardType: widget.keyboardType,
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
