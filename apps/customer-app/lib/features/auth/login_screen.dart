import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import 'signup_screen.dart';

// docx 2.2 — Customer Login. Sign-up (2.1) and Forgot Password (2.5) live in
// signup_screen.dart and onehub_shared's ResetPasswordScreen respectively.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _mobileOrEmail = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await api.post('/auth/customer/login', {
        'mobileOrEmail': _mobileOrEmail.text.trim(),
        'password': _password.text,
      });
      if (mounted) Navigator.of(context).pushReplacementNamed('/dashboard');
    } catch (e) {
      setState(() => _error = 'Could not log in: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'OneHub',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 32),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_error!, style: TextStyle(color: context.statusDanger)),
                ),
              TextField(
                controller: _mobileOrEmail,
                decoration: const InputDecoration(labelText: 'Mobile Number or Email'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 24),
              PrimaryCta(onPressed: _busy ? null : _login, child: const Text('Login')),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ResetPasswordScreen(client: api)),
                ),
                child: const Text('Forgot Password?'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SignupScreen()),
                ),
                child: const Text("New here? Sign up"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
