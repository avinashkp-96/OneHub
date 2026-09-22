import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import 'signup_screen.dart';

// docx 2.4 — Provider Login. Surfaces a distinct message when the account is
// still "Pending Verification" (AuthService.login on the backend throws a
// 401 with that reason specifically, which the pending check below matches).
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
  bool _pendingVerification = false;

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
      _pendingVerification = false;
    });
    try {
      await api.post('/auth/provider/login', {
        'mobileOrEmail': _mobileOrEmail.text.trim(),
        'password': _password.text,
      });
      if (mounted) Navigator.of(context).pushReplacementNamed('/dashboard');
    } catch (e) {
      final message = e.toString();
      setState(() {
        _pendingVerification = message.contains('pending verification');
        _error = _pendingVerification
            ? 'Your account is still pending verification. You can log in once an admin approves your ID proof.'
            : 'Could not log in: $e';
      });
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
                'OneHub for Providers',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 32),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    style: TextStyle(color: _pendingVerification ? context.statusWarning : context.statusDanger),
                  ),
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
