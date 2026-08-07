import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'home_shell.dart';
import '../services/api.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_email.text.isEmpty || _password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email and password required')),
      );
      return;
    }
    
    setState(() => _loading = true);
    
    final ok = await ApiService.login(email: _email.text, password: _password.text);
    
    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid credentials')),
      );

      setState(() => _loading = false);
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            Text('Welcome back', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            const Text(
              'Sign in to see who nearby can lend a hand.',
              style: TextStyle(color: AppColors.inkSoft, fontSize: 14.5),
            ),
            const SizedBox(height: 32),
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
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                      )
                    : const Text('Sign in'),
              ),
            ),
            const SizedBox(height: 16),
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
                      'Mock auth for now — any email and password will work.',
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