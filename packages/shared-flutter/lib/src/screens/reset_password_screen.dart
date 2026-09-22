import 'package:flutter/material.dart';
import '../api_client.dart';
import '../theme/onehub_theme.dart';

/// docx 2.5 "Forgot / Reset Password (Common)" — identical for customer and
/// provider, so it lives here instead of being built twice. Takes the app's
/// [ApiClient] explicitly rather than reaching for a global, since this is
/// meant to be dropped into either app unchanged.
class ResetPasswordScreen extends StatefulWidget {
  final ApiClient client;
  const ResetPasswordScreen({super.key, required this.client});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

enum _Step { enterContact, enterOtpAndPassword, done }

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _mobileOrEmail = TextEditingController();
  final _otp = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmNewPassword = TextEditingController();

  _Step _step = _Step.enterContact;
  bool _busy = false;
  String? _error;

  Future<void> _requestOtp() async {
    if (_mobileOrEmail.text.trim().isEmpty) {
      setState(() => _error = 'Enter your registered mobile number or email.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.client.post('/auth/otp/request', {'mobile': _mobileOrEmail.text.trim()});
      setState(() => _step = _Step.enterOtpAndPassword);
    } catch (e) {
      setState(() => _error = 'Could not send an OTP: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_newPassword.text != _confirmNewPassword.text) {
      setState(() => _error = 'New password and confirmation must match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.client.post('/auth/password/reset', {
        'mobileOrEmail': _mobileOrEmail.text.trim(),
        'otp': _otp.text.trim(),
        'newPassword': _newPassword.text,
        'confirmNewPassword': _confirmNewPassword.text,
      });
      setState(() => _step = _Step.done);
    } catch (e) {
      setState(() => _error = 'Could not reset your password: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_error!, style: TextStyle(color: context.statusDanger)),
                ),
              if (_step == _Step.enterContact) ..._contactStep(),
              if (_step == _Step.enterOtpAndPassword) ..._otpAndPasswordStep(),
              if (_step == _Step.done) ..._doneStep(context),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _contactStep() => [
        TextField(
          controller: _mobileOrEmail,
          decoration: const InputDecoration(labelText: 'Mobile Number or Email'),
        ),
        const SizedBox(height: 20),
        PrimaryCta(onPressed: _busy ? null : _requestOtp, child: const Text('Send OTP')),
      ];

  List<Widget> _otpAndPasswordStep() => [
        TextField(controller: _otp, decoration: const InputDecoration(labelText: 'OTP')),
        const SizedBox(height: 16),
        TextField(
          controller: _newPassword,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'New Password'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmNewPassword,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Confirm New Password'),
        ),
        const SizedBox(height: 20),
        PrimaryCta(onPressed: _busy ? null : _reset, child: const Text('Reset Password')),
      ];

  List<Widget> _doneStep(BuildContext context) => [
        Text('Password reset. Log in with your new password.', style: TextStyle(color: context.statusSuccess)),
        const SizedBox(height: 20),
        PrimaryCta(onPressed: () => Navigator.of(context).pop(), child: const Text('Back to Login')),
      ];
}
