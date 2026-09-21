import 'package:flutter/material.dart';

// docx 2.2 — Customer Login. Sign-up (2.1) and Forgot Password (2.5) are
// natural follow-ups from this screen's footer links; build them alongside it.
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
              Text('OneHub', style: Theme.of(context).textTheme.headlineMedium),
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
              FilledButton(
                // TODO: call ApiClient.post('/auth/customer/login', ...) and
                // navigate on success.
                onPressed: () => Navigator.of(context).pushReplacementNamed('/dashboard'),
                child: const Padding(padding: EdgeInsets.all(12), child: Text('Login')),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: () {}, child: const Text('Forgot Password?')),
              TextButton(onPressed: () {}, child: const Text("New here? Sign up")),
            ],
          ),
        ),
      ),
    );
  }
}
