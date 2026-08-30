import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/api.dart';
import '../theme/colors.dart';
import '../widgets/staggered_entrance.dart';
import 'recovery_codes_page.dart';

class TwoFactorSetupPage extends StatefulWidget {
  const TwoFactorSetupPage({super.key});

  @override
  State<TwoFactorSetupPage> createState() => _TwoFactorSetupPageState();
}

class _TwoFactorSetupPageState extends State<TwoFactorSetupPage> {
  String? _secret;
  String? _otpauthUri;
  final _codeController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void dispose() {
    _codeController.dispose();
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

  Future<void> _setup() async {
    try {
      final res = await Api.post('/api/auth/2fa/setup');
      if (!mounted) return;
      setState(() {
        _secret = res['secret'] as String;
        _otpauthUri = res['otpauth_uri'] as String;
      });
    } catch (e) {
      if (!mounted) return;
      _snack(describeError(e));
    }
  }

  Future<void> _enable() async {
    final code = _codeController.text.trim();
    if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
      _snack('Please enter a valid 6-digit code');
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await Api.post('/api/auth/2fa/enable', body: {'code': code});
      if (!mounted) return;
      final recoveryCodes = (res['recovery_codes'] as List).cast<String>();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RecoveryCodesPage(recoveryCodes: recoveryCodes),
        ),
      );
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
                  'Set up two-factor authentication',
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
                  'Scan this QR code with your authenticator app, then enter the 6-digit code to verify.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    fontSize: 14.5,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (_secret != null) ...[
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
                    child: Column(
                      children: [
                        Container(
                          width: 200,
                          height: 200,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: QrImageView(
                            data: _otpauthUri!,
                            version: QrVersions.auto,
                            size: 168,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Or enter this code manually:',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: _secret!));
                            _snack('Secret copied', isError: false);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkPaper
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.darkBorder.withValues(alpha: 0.5)
                                    : AppColors.inkSoft.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Text(
                              _secret!,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2.0,
                                color: theme.colorScheme.onSurface,
                              ),
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
                  child: _FieldLabel(label: 'Verification code'),
                ),
                const SizedBox(height: 8),
                StaggeredItem(
                  index: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSand.withValues(alpha: 0.9)
                          : Colors.white.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder.withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.9),
                        width: 1.2,
                      ),
                    ),
                    child: TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      style: TextStyle(
                        fontSize: 14.5,
                        color: theme.colorScheme.onSurface,
                        height: 1.2,
                        letterSpacing: 4.0,
                      ),
                      decoration: InputDecoration(
                        hintText: '000000',
                        hintStyle: TextStyle(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4),
                          fontSize: 14.5,
                        ),
                        counterText: '',
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        prefixIcon: Icon(
                          Icons.pin_outlined,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
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
                  ),
                ),
                const SizedBox(height: 24),
                StaggeredItem(
                  index: 5,
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _enable,
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
                          : const Text('Enable two-factor authentication'),
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 40),
                const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppColors.terracotta,
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
