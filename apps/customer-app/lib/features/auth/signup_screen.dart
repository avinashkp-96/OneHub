import 'dart:async';
import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import '../../core/widgets/field_label.dart';
import '../../core/widgets/otp_input.dart';

// docx 2.1 — Customer Sign Up. 3-step flow per the Figma Make reference:
// signup form -> OTP verification -> success screen.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

enum _Step { form, otp, success }

const _resendCooldownSeconds = 30;

class _SignupScreenState extends State<SignupScreen> {
  final _fullName = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _city = TextEditingController();

  _Step _step = _Step.form;
  String _otp = '';
  bool _acceptedTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _busy = false;
  String? _error;

  Timer? _resendTimer;
  int _resendSecondsLeft = 0;

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  String? _validateForm() {
    if (_fullName.text.trim().isEmpty) return 'Full name is required.';
    if (!RegExp(r'^[0-9]{10}$').hasMatch(_mobile.text.trim())) return 'Enter a valid 10-digit mobile number.';
    if (_password.text.length < 6) return 'Password must be at least 6 characters.';
    if (_password.text != _confirmPassword.text) return 'Password and confirmation must match.';
    if (_city.text.trim().isEmpty) return 'City / Location is required.';
    if (!_acceptedTerms) return 'Accept the Terms & Conditions to continue.';
    return null;
  }

  Future<void> _submitForm() async {
    final validationError = _validateForm();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await api.post('/auth/otp/request', {'mobile': _mobile.text.trim()});
      setState(() => _step = _Step.otp);
      _startResendTimer();
    } catch (e) {
      setState(() => _error = 'Could not send an OTP: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsLeft = _resendCooldownSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSecondsLeft <= 1) {
        timer.cancel();
        setState(() => _resendSecondsLeft = 0);
      } else {
        setState(() => _resendSecondsLeft -= 1);
      }
    });
  }

  Future<void> _resendOtp() async {
    if (_resendSecondsLeft > 0) return;
    try {
      await api.post('/auth/otp/request', {'mobile': _mobile.text.trim()});
      _startResendTimer();
    } catch (e) {
      setState(() => _error = 'Could not resend the OTP: $e');
    }
  }

  Future<void> _verifyAndCreateAccount() async {
    if (_otp.length != 6) {
      setState(() => _error = 'Enter the 6-digit code.');
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
        'otp': _otp,
        if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
        'password': _password.text,
        'confirmPassword': _confirmPassword.text,
        'city': _city.text.trim(),
      });
      _resendTimer?.cancel();
      setState(() => _step = _Step.success);
    } catch (e) {
      setState(() => _error = 'Could not verify that code: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _useGpsLocation() {
    // TODO: wire up real device/browser geolocation. Not implemented yet —
    // this is a UI-only placeholder so the flow isn't blocked on it.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Location detection is not set up yet — enter your city manually.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _step == _Step.otp
          ? AppBar(
              leading: IconButton(
                icon: const Icon(OneHubIcons.arrowLeft),
                onPressed: () => setState(() => _step = _Step.form),
              ),
            )
          : null,
      body: SafeArea(
        child: GlowBackground(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: switch (_step) {
              _Step.form => _FormStep(
                fullName: _fullName,
                mobile: _mobile,
                email: _email,
                password: _password,
                confirmPassword: _confirmPassword,
                city: _city,
                obscurePassword: _obscurePassword,
                obscureConfirmPassword: _obscureConfirmPassword,
                onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
                onToggleConfirmPassword: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                acceptedTerms: _acceptedTerms,
                onAcceptedTermsChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                onUseGps: _useGpsLocation,
                error: _error,
                busy: _busy,
                onSubmit: _submitForm,
                onBackToLogin: () => Navigator.of(context).pop(),
              ),
            _Step.otp => _OtpStep(
                mobile: _mobile.text.trim(),
                onChanged: (code) => _otp = code,
                resendSecondsLeft: _resendSecondsLeft,
                onResend: _resendOtp,
                error: _error,
                busy: _busy,
                onVerify: _verifyAndCreateAccount,
              ),
              _Step.success => _SuccessStep(onGoToDashboard: () => Navigator.of(context).pushReplacementNamed('/dashboard')),
            },
          ),
        ),
      ),
    );
  }
}

class _FormStep extends StatelessWidget {
  final TextEditingController fullName, mobile, email, password, confirmPassword, city;
  final bool obscurePassword, obscureConfirmPassword, acceptedTerms, busy;
  final VoidCallback onTogglePassword, onToggleConfirmPassword, onUseGps, onSubmit, onBackToLogin;
  final ValueChanged<bool?> onAcceptedTermsChanged;
  final String? error;

  const _FormStep({
    required this.fullName,
    required this.mobile,
    required this.email,
    required this.password,
    required this.confirmPassword,
    required this.city,
    required this.obscurePassword,
    required this.obscureConfirmPassword,
    required this.onTogglePassword,
    required this.onToggleConfirmPassword,
    required this.acceptedTerms,
    required this.onAcceptedTermsChanged,
    required this.onUseGps,
    required this.error,
    required this.busy,
    required this.onSubmit,
    required this.onBackToLogin,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TintedBadge(label: 'NEW ACCOUNT', color: OneHubColors.primary),
            SizedBox(width: 8),
            TintedBadge(label: 'FREE SIGNUP', color: OneHubColors.accentPurple),
          ],
        ),
        const SizedBox(height: 16),
        Text('Create Account', textAlign: TextAlign.center, style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          'Join us and discover nearby providers',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: textTheme.bodySmall?.color?.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 32),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (error != null) Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(error!, style: TextStyle(color: context.statusDanger))),
                const FieldLabel('FULL NAME', required: true, icon: OneHubIcons.user),
                const SizedBox(height: 6),
                TextField(controller: fullName, decoration: const InputDecoration(hintText: 'John Doe')),
                const SizedBox(height: 16),
                const FieldLabel('MOBILE NUMBER', required: true, icon: OneHubIcons.phone),
                const SizedBox(height: 6),
                TextField(
                  controller: mobile,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(hintText: '10-digit number'),
                ),
                const SizedBox(height: 16),
                const FieldLabel('EMAIL ID (optional)', icon: OneHubIcons.email),
                const SizedBox(height: 6),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'you@example.com'),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const FieldLabel('PASSWORD', required: true, icon: OneHubIcons.lock),
                          const SizedBox(height: 6),
                          TextField(
                            controller: password,
                            obscureText: obscurePassword,
                            decoration: InputDecoration(
                              hintText: 'Min. 6 chars',
                              suffixIcon: IconButton(
                                icon: Icon(obscurePassword ? OneHubIcons.hide : OneHubIcons.show),
                                onPressed: onTogglePassword,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const FieldLabel('CONFIRM', required: true, icon: OneHubIcons.confirmed),
                          const SizedBox(height: 6),
                          TextField(
                            controller: confirmPassword,
                            obscureText: obscureConfirmPassword,
                            decoration: InputDecoration(
                              hintText: 'Re-enter',
                              suffixIcon: IconButton(
                                icon: Icon(obscureConfirmPassword ? OneHubIcons.hide : OneHubIcons.show),
                                onPressed: onToggleConfirmPassword,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const FieldLabel('CITY / LOCATION', required: true, icon: OneHubIcons.location),
                const SizedBox(height: 6),
                TextField(
                  controller: city,
                  decoration: InputDecoration(
                    hintText: 'e.g. Mumbai',
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Center(
                        widthFactor: 1,
                        child: TintedBadge(label: 'GPS', color: OneHubColors.primary, onTap: onUseGps),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: acceptedTerms,
                  onChanged: onAcceptedTermsChanged,
                  title: Text.rich(
                    TextSpan(
                      style: textTheme.bodyMedium,
                      children: [
                        const TextSpan(text: 'I agree to the '),
                        TextSpan(
                          text: 'Terms & Conditions',
                          style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
                        ),
                        const TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                PrimaryCta(onPressed: busy ? null : onSubmit, child: const Text('Create Account')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Already have an account? ', style: textTheme.bodyMedium),
            GestureDetector(
              onTap: onBackToLogin,
              child: Text(
                'Login',
                style: textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OtpStep extends StatelessWidget {
  final String mobile;
  final ValueChanged<String> onChanged;
  final int resendSecondsLeft;
  final VoidCallback onResend;
  final String? error;
  final bool busy;
  final VoidCallback onVerify;

  const _OtpStep({
    required this.mobile,
    required this.onChanged,
    required this.resendSecondsLeft,
    required this.onResend,
    required this.error,
    required this.busy,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text('Phone Verification', textAlign: TextAlign.center, style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          'Enter the 6-digit code sent to +91 $mobile',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: textTheme.bodySmall?.color?.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 32),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (error != null) Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(error!, style: TextStyle(color: context.statusDanger))),
                OtpInput(onChanged: onChanged),
                const SizedBox(height: 20),
                Center(
                  child: resendSecondsLeft > 0
                      ? Text('Resend code in 0:${resendSecondsLeft.toString().padLeft(2, '0')}', style: textTheme.bodySmall)
                      : TextButton(onPressed: onResend, child: const Text('Resend code')),
                ),
                const SizedBox(height: 12),
                PrimaryCta(onPressed: busy ? null : onVerify, child: const Text('Verify & Create Account')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SuccessStep extends StatelessWidget {
  final VoidCallback onGoToDashboard;
  const _SuccessStep({required this.onGoToDashboard});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 64),
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(color: context.statusSuccess.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(OneHubIcons.successCheck, color: context.statusSuccess, size: 48),
          ),
        ),
        const SizedBox(height: 24),
        Text('Account Created!', textAlign: TextAlign.center, style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          'Your account has been created successfully.',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 32),
        PrimaryCta(onPressed: onGoToDashboard, child: const Text('Go to Dashboard')),
      ],
    );
  }
}
