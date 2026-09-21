import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';

// docx 2.4 — Provider Login. Must surface a blocked-with-status-message state
// when the account is still "Pending Verification" (see AuthService.login on
// the backend, which throws for that case).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _mobileOrEmail = TextEditingController();
  final _password = TextEditingController();

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
              PrimaryCta(
                // TODO: call ApiClient.post('/auth/provider/login', ...); show
                // the "Pending Verification" message inline on a 401 with that reason.
                onPressed: () => Navigator.of(context).pushReplacementNamed('/dashboard'),
                child: const Text('Login'),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: () {}, child: const Text('Forgot Password?')),
            ],
          ),
        ),
      ),
    );
  }
}
