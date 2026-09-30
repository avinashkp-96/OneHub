import 'package:flutter/material.dart';
import '../api_client.dart';
import '../theme/onehub_colors.dart';
import '../theme/onehub_icons.dart';
import '../theme/onehub_theme.dart';
import '../theme/glow_card.dart';

/// docx 2.5 "Forgot / Reset Password (Common)" — identical for customer and
/// provider, so it lives here instead of being built twice. Takes the app's
/// [ApiClient] explicitly rather than reaching for a global, since this is
/// meant to be dropped into either app unchanged.
/// Restyled to match the current OneHub design system (no new reference —
/// applied on request): PageGlow background, a back-only AppBar plus an
/// in-body heading, a single GlowCard holding the active step's fields (the
/// contact step and the OTP/new-password step are two distinct forms in
/// sequence, so each gets its own card rather than sharing one across the
/// step transition), and a success step matching SignupScreen's exactly
/// (icon-in-circle, heading, subtitle, CTA).
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
  bool _obscureNewPassword = true;
  bool _obscureConfirmNewPassword = true;
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
      await widget.client
          .post('/auth/otp/request', {'mobile': _mobileOrEmail.text.trim()});
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;

    return Scaffold(
      appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.of(context).pop())),
      body: PageGlow(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: OneHubTheme.pageMargin,
                      vertical: OneHubTheme.pagePaddingY),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: switch (_step) {
                      _Step.enterContact =>
                        _contactStep(textPrimary, textSecondary),
                      _Step.enterOtpAndPassword =>
                        _otpAndPasswordStep(textPrimary, textSecondary),
                      _Step.done =>
                        _doneStep(context, textPrimary, textSecondary),
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _contactStep(Color textPrimary, Color textSecondary) => [
        Text('Reset your password',
            textAlign: TextAlign.center,
            style: OneHubTextStyles.pageHeading(textPrimary)),
        const SizedBox(height: 8),
        Text(
          "We'll text a code to your registered number or email to verify it's you.",
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
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_error!,
                        style: TextStyle(color: context.statusDanger)),
                  ),
                const _FieldLabel('MOBILE NUMBER OR EMAIL',
                    icon: OneHubIcons.user),
                const SizedBox(height: OneHubTheme.gapFieldInternals),
                TextField(
                  controller: _mobileOrEmail,
                  decoration: const InputDecoration(
                      hintText: '10-digit number or email'),
                ),
                const SizedBox(height: OneHubTheme.sectionGap),
                PrimaryCta(
                    onPressed: _busy ? null : _requestOtp,
                    child: const Text('Send OTP')),
              ],
            ),
          ),
        ),
      ];

  List<Widget> _otpAndPasswordStep(Color textPrimary, Color textSecondary) => [
        Text('Enter the code',
            textAlign: TextAlign.center,
            style: OneHubTextStyles.pageHeading(textPrimary)),
        const SizedBox(height: 8),
        Text(
          'Then choose a new password.',
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
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_error!,
                        style: TextStyle(color: context.statusDanger)),
                  ),
                const _FieldLabel('OTP', icon: OneHubIcons.confirmed),
                const SizedBox(height: OneHubTheme.gapFieldInternals),
                TextField(
                    controller: _otp,
                    decoration:
                        const InputDecoration(hintText: '6-digit code')),
                const SizedBox(height: OneHubTheme.sectionGap),
                const _FieldLabel('NEW PASSWORD', icon: OneHubIcons.lock),
                const SizedBox(height: OneHubTheme.gapFieldInternals),
                TextField(
                  controller: _newPassword,
                  obscureText: _obscureNewPassword,
                  decoration: InputDecoration(
                    hintText: 'Min. 6 chars',
                    suffixIcon: IconButton(
                      icon: Icon(_obscureNewPassword
                          ? OneHubIcons.hide
                          : OneHubIcons.show),
                      onPressed: () => setState(
                          () => _obscureNewPassword = !_obscureNewPassword),
                    ),
                  ),
                ),
                const SizedBox(height: OneHubTheme.sectionGap),
                const _FieldLabel('CONFIRM NEW PASSWORD',
                    icon: OneHubIcons.confirmed),
                const SizedBox(height: OneHubTheme.gapFieldInternals),
                TextField(
                  controller: _confirmNewPassword,
                  obscureText: _obscureConfirmNewPassword,
                  decoration: InputDecoration(
                    hintText: 'Re-enter',
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmNewPassword
                          ? OneHubIcons.hide
                          : OneHubIcons.show),
                      onPressed: () => setState(() =>
                          _obscureConfirmNewPassword =
                              !_obscureConfirmNewPassword),
                    ),
                  ),
                ),
                const SizedBox(height: OneHubTheme.sectionGap),
                PrimaryCta(
                    onPressed: _busy ? null : _reset,
                    child: const Text('Reset Password')),
              ],
            ),
          ),
        ),
      ];

  List<Widget> _doneStep(
          BuildContext context, Color textPrimary, Color textSecondary) =>
      [
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
        Text('Password Reset!',
            textAlign: TextAlign.center,
            style: OneHubTextStyles.pageHeading(textPrimary)),
        const SizedBox(height: 8),
        Text(
          'Log in with your new password.',
          textAlign: TextAlign.center,
          style: OneHubTextStyles.bodyText(textSecondary),
        ),
        const SizedBox(height: OneHubTheme.sectionGap),
        PrimaryCta(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back to Login')),
      ];
}

/// Small uppercase field label, duplicated from the customer app's
/// `core/widgets/field_label.dart` rather than shared, since this package
/// can't depend on either app — a candidate to promote into this package if
/// a third consumer needs it (flagged, not auto-promoted, per the
/// reusability framework).
class _FieldLabel extends StatelessWidget {
  final String text;
  final IconData icon;
  const _FieldLabel(this.text, {required this.icon});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: OneHubTheme.gapIconLabel),
        Text(text, style: OneHubTextStyles.fieldLabel(color)),
      ],
    );
  }
}
