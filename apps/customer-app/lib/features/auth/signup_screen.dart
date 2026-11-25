import 'dart:async';
import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import '../../core/widgets/field_label.dart';
import '../../core/widgets/otp_input.dart';
import '../addresses/address_form.dart';

// docx 2.1 — Customer Sign Up. 3-step flow per a formal style guide PDF the
// user supplied directly ("Component library and visual tokens extracted
// from the signup screen"): signup form -> OTP verification -> success
// screen. No badges above the heading — an earlier reading of the
// underlying Figma file's live rendered page showed "NEW ACCOUNT"/"FREE
// SIGNUP" pills there, but the actual reference screenshot that came with
// this PDF doesn't have them; the style guide's own "Badges" section is a
// component-library showcase, not a spec for this screen's layout.
class SignupScreen extends StatefulWidget {
  /// Asks where the address is; tests pass one to skip the sheet and GPS.
  final LocationPicker? pickLocation;
  const SignupScreen({super.key, this.pickLocation});

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
  // The customer's first saved address (Home), where providers come to.
  final _address = AddressDraft();

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
    _address.dispose();
    super.dispose();
  }

  // Problems shown under their own field on the form step: name, mobile,
  // email, password, confirm, the address fields, terms. [_error] holds what
  // belongs to no field, and on the code step, the code's problem.
  final Map<String, String> _fieldErrors = {};
  // The code the API sent back while no SMS is sent (never in production).
  String? _testCode;

  static const _apiFields = {
    'mobile': ['mobile'],
    'email': ['email'],
    'confirm': ['match'],
    'password': ['password'],
    'name': ['fullname', 'name'],
    ...AddressDraft.apiFields,
  };

  void _clear(String field) {
    if (_fieldErrors.remove(field) != null) setState(() {});
  }

  /// Every problem on the form, keyed by the field it belongs to.
  Map<String, String> _validateForm() {
    final email = _email.text.trim();
    return {
      if (_fullName.text.trim().isEmpty) 'name': 'Enter your full name.',
      if (!RegExp(r'^[0-9]{10}$').hasMatch(_mobile.text.trim()))
        'mobile': 'Enter a 10-digit mobile number.',
      if (email.isNotEmpty &&
          !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email))
        'email': 'Enter a valid email address.',
      if (_password.text.length < 6)
        'password': 'Password must be at least 6 characters.',
      if (_password.text != _confirmPassword.text)
        'confirm': 'The passwords do not match.',
      ..._address.problems(),
      if (!_acceptedTerms) 'terms': 'Accept the Terms & Conditions to continue.',
    };
  }

  // Puts [e] under its field (back on the form step if it is about one),
  // else on the current step.
  void _fail(Object e) {
    final onCode = errorField(e, const {'otp': ['otp', 'code']}) != null;
    final field = onCode ? null : errorField(e, _apiFields);
    setState(() {
      if (field != null) {
        _fieldErrors[field] = userMessage(e);
        _step = _Step.form;
        _error = null;
      } else {
        _error = userMessage(e);
      }
    });
  }

  Future<void> _submitForm() async {
    final problems = _validateForm();
    setState(() {
      _fieldErrors
        ..clear()
        ..addAll(problems);
      _error = null;
    });
    if (problems.isNotEmpty) return;
    setState(() => _busy = true);
    try {
      final reply =
          await api.post('/auth/otp/request', {'mobile': _mobile.text.trim()});
      setState(() {
        _testCode = testCodeFrom(reply);
        _step = _Step.otp;
      });
      _startResendTimer();
    } catch (e) {
      _fail(e);
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
      final reply =
          await api.post('/auth/otp/request', {'mobile': _mobile.text.trim()});
      setState(() => _testCode = testCodeFrom(reply));
      _startResendTimer();
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _verifyAndCreateAccount() async {
    if (_otp.length != 6) {
      setState(() => _error = 'Enter the 6-digit code we sent you.');
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
        'address': _address.toAddress().toJson(),
      });
      _resendTimer?.cancel();
      setState(() => _step = _Step.success);
    } catch (e) {
      _fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
      body: PageGlow(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: OneHubTheme.pageMargin,
                vertical: OneHubTheme.pagePaddingY),
            child: switch (_step) {
              _Step.form => _FormStep(
                  fullName: _fullName,
                  mobile: _mobile,
                  email: _email,
                  password: _password,
                  confirmPassword: _confirmPassword,
                  obscurePassword: _obscurePassword,
                  obscureConfirmPassword: _obscureConfirmPassword,
                  onTogglePassword: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  onToggleConfirmPassword: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword),
                  fieldErrors: _fieldErrors,
                  onEdited: _clear,
                  address: AddressFields(
                      draft: _address,
                      enabled: !_busy,
                      pickLocation: widget.pickLocation,
                      errors: _fieldErrors,
                      onEdited: _clear),
                  acceptedTerms: _acceptedTerms,
                  onAcceptedTermsChanged: (v) => setState(() {
                        _acceptedTerms = v ?? false;
                        _fieldErrors.remove('terms');
                      }),
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
                  testCode: _testCode,
                  busy: _busy,
                  onVerify: _verifyAndCreateAccount,
                ),
              _Step.success => _SuccessStep(
                  onGoToDashboard: () =>
                      Navigator.of(context).pushReplacementNamed('/dashboard')),
            },
          ),
        ),
      ),
    );
  }
}

class _FormStep extends StatelessWidget {
  final TextEditingController fullName,
      mobile,
      email,
      password,
      confirmPassword;
  final bool obscurePassword, obscureConfirmPassword, acceptedTerms, busy;
  final VoidCallback onTogglePassword,
      onToggleConfirmPassword,
      onSubmit,
      onBackToLogin;
  final ValueChanged<bool?> onAcceptedTermsChanged;
  final String? error;
  final Widget address;
  final Map<String, String> fieldErrors;
  final ValueChanged<String> onEdited;

  const _FormStep({
    required this.address,
    required this.fieldErrors,
    required this.onEdited,
    required this.fullName,
    required this.mobile,
    required this.email,
    required this.password,
    required this.confirmPassword,
    required this.obscurePassword,
    required this.obscureConfirmPassword,
    required this.onTogglePassword,
    required this.onToggleConfirmPassword,
    required this.acceptedTerms,
    required this.onAcceptedTermsChanged,
    required this.error,
    required this.busy,
    required this.onSubmit,
    required this.onBackToLogin,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Exact copy from the style guide's type sample, period included.
        Text('Create Account.',
            textAlign: TextAlign.center,
            style: OneHubTextStyles.pageHeading(textPrimary)),
        const SizedBox(height: 8),
        Text(
          'Join and discover nearby service providers',
          textAlign: TextAlign.center,
          style: OneHubTextStyles.bodyText(textSecondary),
        ),
        const SizedBox(height: OneHubTheme.sectionGap),
        GlowCard(
          child: Padding(
            padding: const EdgeInsets.all(OneHubTheme.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (error != null)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(error!,
                          style: TextStyle(color: context.statusDanger))),
                const FieldLabel('FULL NAME',
                    required: true, icon: OneHubIcons.user),
                const SizedBox(height: OneHubTheme.gapFieldInternals),
                TextField(
                    controller: fullName,
                    onChanged: (_) => onEdited('name'),
                    decoration: InputDecoration(
                        hintText: 'John Doe', errorText: fieldErrors['name'])),
                const SizedBox(height: OneHubTheme.sectionGap),
                const FieldLabel('MOBILE NUMBER',
                    required: true, icon: OneHubIcons.phone),
                const SizedBox(height: OneHubTheme.gapFieldInternals),
                TextField(
                  controller: mobile,
                  keyboardType: TextInputType.phone,
                  onChanged: (_) => onEdited('mobile'),
                  decoration: InputDecoration(
                      hintText: '10-digit number',
                      errorText: fieldErrors['mobile']),
                ),
                const SizedBox(height: OneHubTheme.sectionGap),
                const FieldLabel('EMAIL ID (optional)',
                    icon: OneHubIcons.email),
                const SizedBox(height: OneHubTheme.gapFieldInternals),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => onEdited('email'),
                  decoration: InputDecoration(
                      hintText: 'you@example.com',
                      errorText: fieldErrors['email']),
                ),
                const SizedBox(height: OneHubTheme.sectionGap),
                const FieldLabel('PASSWORD',
                    required: true, icon: OneHubIcons.lock),
                const SizedBox(height: OneHubTheme.gapFieldInternals),
                TextField(
                  controller: password,
                  obscureText: obscurePassword,
                  onChanged: (_) => onEdited('password'),
                  decoration: InputDecoration(
                    hintText: 'Min. 6 chars',
                    errorText: fieldErrors['password'],
                    suffixIcon: IconButton(
                      icon: Icon(obscurePassword
                          ? OneHubIcons.hide
                          : OneHubIcons.show),
                      onPressed: onTogglePassword,
                    ),
                  ),
                ),
                const SizedBox(height: OneHubTheme.sectionGap),
                const FieldLabel('CONFIRM PASSWORD',
                    required: true, icon: OneHubIcons.confirmed),
                const SizedBox(height: OneHubTheme.gapFieldInternals),
                TextField(
                  controller: confirmPassword,
                  obscureText: obscureConfirmPassword,
                  onChanged: (_) => onEdited('confirm'),
                  decoration: InputDecoration(
                    hintText: 'Re-enter',
                    errorText: fieldErrors['confirm'],
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirmPassword
                          ? OneHubIcons.hide
                          : OneHubIcons.show),
                      onPressed: onToggleConfirmPassword,
                    ),
                  ),
                ),
                const SizedBox(height: OneHubTheme.sectionGap),
                Text('YOUR ADDRESS',
                    style: OneHubTextStyles.pageHeading(textPrimary)
                        .copyWith(fontSize: 16)),
                const SizedBox(height: 4),
                Text('Where providers come for your jobs. You can add more later.',
                    style: OneHubTextStyles.bodyText(textSecondary)
                        .copyWith(fontSize: 13)),
                const SizedBox(height: 12),
                address,
                const SizedBox(height: 12),
                // Its own Material, because GlowCard paints a coloured box
                // that would otherwise hide the tile's ink splash.
                Material(
                  type: MaterialType.transparency,
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: acceptedTerms,
                    onChanged: onAcceptedTermsChanged,
                    title: TermsAgreementText(
                        textColor: textSecondary, linkColor: primary),
                  ),
                ),
                FieldError(fieldErrors['terms']),
                const SizedBox(height: 8),
                PrimaryCta(
                    onPressed: busy ? null : onSubmit,
                    child: const Text('Create Account')),
              ],
            ),
          ),
        ),
        const SizedBox(height: OneHubTheme.sectionGap),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Already have an account? ',
                style: OneHubTextStyles.linkText(textSecondary)),
            GestureDetector(
              onTap: onBackToLogin,
              child: Text('Login', style: OneHubTextStyles.linkText(primary)),
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
  final String? testCode;
  final bool busy;
  final VoidCallback onVerify;

  const _OtpStep({
    required this.testCode,
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Phone Verification',
            textAlign: TextAlign.center,
            style: OneHubTextStyles.pageHeading(textPrimary)),
        const SizedBox(height: 8),
        Text(
          'Enter the 6-digit code sent to +91 $mobile',
          textAlign: TextAlign.center,
          style: OneHubTextStyles.bodyText(textSecondary),
        ),
        const SizedBox(height: OneHubTheme.sectionGap),
        GlowCard(
          child: Padding(
            padding: const EdgeInsets.all(OneHubTheme.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OtpInput(onChanged: onChanged),
                Center(child: FieldError(error)),
                Center(child: TestCodeHint(testCode)),
                const SizedBox(height: OneHubTheme.sectionGap),
                Center(
                  child: resendSecondsLeft > 0
                      ? Text(
                          'Resend code in 0:${resendSecondsLeft.toString().padLeft(2, '0')}',
                          style: OneHubTextStyles.bodyText(textMuted))
                      : TextButton(
                          onPressed: onResend,
                          child: Text('Resend code',
                              style: OneHubTextStyles.linkText(primary))),
                ),
                const SizedBox(height: 12),
                PrimaryCta(
                    onPressed: busy ? null : onVerify,
                    child: const Text('Verify & Create Account')),
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
                color: context.statusSuccess.withValues(alpha: 0.12),
                shape: BoxShape.circle),
            child: Icon(OneHubIcons.successCheck,
                color: context.statusSuccess, size: 48),
          ),
        ),
        const SizedBox(height: 24),
        Text('Account Created!',
            textAlign: TextAlign.center,
            style: OneHubTextStyles.pageHeading(textPrimary)),
        const SizedBox(height: 8),
        Text(
          'Your account has been created successfully.',
          textAlign: TextAlign.center,
          style: OneHubTextStyles.bodyText(textSecondary),
        ),
        const SizedBox(height: OneHubTheme.sectionGap),
        PrimaryCta(
            onPressed: onGoToDashboard, child: const Text('Go to Dashboard')),
      ],
    );
  }
}
