import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';

// docx 2.1 — Customer Sign Up.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _fullName = TextEditingController();
  final _mobile = TextEditingController();
  final _otp = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _city = TextEditingController();

  bool _otpSent = false;
  bool _acceptedTerms = false;
  bool _busy = false;
  String? _error;

  Future<void> _sendOtp() async {
    if (!RegExp(r'^[0-9]{10}$').hasMatch(_mobile.text.trim())) {
      setState(() => _error = 'Enter a valid 10-digit mobile number.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await api.post('/auth/otp/request', {'mobile': _mobile.text.trim()});
      setState(() => _otpSent = true);
    } catch (e) {
      setState(() => _error = 'Could not send an OTP: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _createAccount() async {
    if (!_otpSent) {
      setState(() => _error = 'Verify your mobile number first.');
      return;
    }
    if (_password.text != _confirmPassword.text) {
      setState(() => _error = 'Password and confirmation must match.');
      return;
    }
    if (!_acceptedTerms) {
      setState(() => _error = 'Accept the Terms & Conditions to continue.');
      return;
    }
    if (_fullName.text.trim().isEmpty || _city.text.trim().isEmpty) {
      setState(() => _error = 'Full name and city are required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await api.post('/auth/customer/signup', {
        'fullName': _fullName.text.trim(),
        'mobile': _mobile.text.trim(),
        'otp': _otp.text.trim(),
        if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
        'password': _password.text,
        'confirmPassword': _confirmPassword.text,
        'city': _city.text.trim(),
      });
      if (mounted) Navigator.of(context).pushReplacementNamed('/dashboard');
    } catch (e) {
      setState(() => _error = 'Could not create your account: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(_error!, style: TextStyle(color: context.statusDanger)),
            ),
          TextField(controller: _fullName, decoration: const InputDecoration(labelText: 'Full Name')),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _mobile,
                  keyboardType: TextInputType.phone,
                  enabled: !_otpSent,
                  decoration: const InputDecoration(labelText: 'Mobile Number'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: _otpSent || _busy ? null : _sendOtp, child: const Text('Send OTP')),
            ],
          ),
          if (_otpSent) ...[
            const SizedBox(height: 16),
            TextField(controller: _otp, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'OTP')),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email ID (optional)'),
          ),
          const SizedBox(height: 16),
          TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmPassword,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirm Password'),
          ),
          const SizedBox(height: 16),
          TextField(controller: _city, decoration: const InputDecoration(labelText: 'City / Location')),
          const SizedBox(height: 16),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _acceptedTerms,
            onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
            title: const Text('I accept the Terms & Conditions'),
          ),
          const SizedBox(height: 8),
          PrimaryCta(onPressed: _busy ? null : _createAccount, child: const Text('Create Account')),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Already have an account? Login'),
          ),
        ],
      ),
    );
  }
}
