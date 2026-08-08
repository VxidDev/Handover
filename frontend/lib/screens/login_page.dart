import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme/colors.dart';
import 'home_shell.dart';

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

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    final name = _name.text.trim();
    if (email.isEmpty || password.isEmpty || (_mode == AuthMode.signUp && name.isEmpty)) {
      _snack(_mode == AuthMode.signUp
          ? 'Name, email and password required'
          : 'Email and password required');
      return;
    }
    setState(() => _loading = true);
    try {
      final body = _mode == AuthMode.signUp
          ? {'email': email, 'password': password, 'name': name, 'lat': Api.demoLat, 'lng': Api.demoLng}
          : {'email': email, 'password': password};
      final res = await Api.post(
        _mode == AuthMode.signUp ? '/api/auth/signup' : '/api/auth/login',
        body: body,
      );
      final user = (res as Map<String, dynamic>)['user'] as Map<String, dynamic>;
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
    setState(() {
      _mode = _mode == AuthMode.signIn ? AuthMode.signUp : AuthMode.signIn;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSignup = _mode == AuthMode.signUp;
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
              color: AppColors.ink,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.sand,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              isSignup ? 'Create your account' : 'Welcome back',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              isSignup
                  ? 'Offer a skill, and neighbors nearby will find you.'
                  : 'Sign in to see who nearby can lend a hand.',
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 14.5),
            ),
            const SizedBox(height: 32),
            if (isSignup) ...[
              const Text('Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Jane Doe',
                  prefixIcon: Icon(Icons.badge_outlined, color: AppColors.inkFaint),
                ),
              ),
              const SizedBox(height: 18),
            ],
            const Text('Email', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
            const SizedBox(height: 8),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'you@example.com',
                prefixIcon: Icon(Icons.mail_outline_rounded, color: AppColors.inkFaint),
              ),
            ),
            const SizedBox(height: 18),
            const Text('Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
            const SizedBox(height: 8),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: '••••••••',
                prefixIcon: Icon(Icons.lock_outline_rounded, color: AppColors.inkFaint),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                      )
                    : Text(isSignup ? 'Create account' : 'Sign in'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loading ? null : _toggleMode,
              child: Text(isSignup ? 'I already have an account — sign in' : 'New here? Create an account'),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.sand,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.inkFaint),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Demo accounts (password: demo1234): maya, diego, owen, priya @example.com',
                      style: TextStyle(fontSize: 12, color: AppColors.inkFaint.withValues(alpha: 0.95)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}