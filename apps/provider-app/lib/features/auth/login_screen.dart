import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import '../../core/widgets/field_label.dart';
import 'signup_screen.dart';

// docx 2.4 — Provider Login. Surfaces a distinct message when the account is
// still "Pending Verification" (AuthService.login on the backend throws a
// 401 with that reason specifically, which the pending check below matches).
// Restyled to match the customer app's login screen (no new reference —
// applied on request): PageGlow, centered heading, a single GlowCard with
// FieldLabel-above-field inputs and a password show/hide toggle.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _mobileOrEmail = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscurePassword = true;
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
      if (!mounted) return;
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
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
                    children: [
                      Text('OneHub for Providers',
                          textAlign: TextAlign.center,
                          style: OneHubTextStyles.pageHeading(textPrimary)),
                      const SizedBox(height: 8),
                      Text(
                        'Log in to receive and manage service requests',
                        textAlign: TextAlign.center,
                        style: OneHubTextStyles.bodyText(textSecondary),
                      ),
                      const SizedBox(height: OneHubTheme.sectionGap),
                      GlowCard(
                        child: Padding(
                          padding:
                              const EdgeInsets.all(OneHubTheme.cardPadding),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_error != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                        color: _pendingVerification
                                            ? context.statusWarning
                                            : context.statusDanger),
                                  ),
                                ),
                              const FieldLabel('MOBILE NUMBER OR EMAIL',
                                  icon: OneHubIcons.user),
                              const SizedBox(
                                  height: OneHubTheme.gapFieldInternals),
                              TextField(
                                controller: _mobileOrEmail,
                                decoration: const InputDecoration(
                                    hintText: '10-digit number or email'),
                              ),
                              const SizedBox(height: OneHubTheme.sectionGap),
                              const FieldLabel('PASSWORD',
                                  icon: OneHubIcons.lock),
                              const SizedBox(
                                  height: OneHubTheme.gapFieldInternals),
                              TextField(
                                controller: _password,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  hintText: 'Your password',
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscurePassword
                                        ? OneHubIcons.hide
                                        : OneHubIcons.show),
                                    onPressed: () => setState(() =>
                                        _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            ResetPasswordScreen(client: api)),
                                  ),
                                  child: Text('Forgot Password?',
                                      style:
                                          OneHubTextStyles.linkText(primary)),
                                ),
                              ),
                              const SizedBox(height: 8),
                              PrimaryCta(
                                  onPressed: _busy ? null : _login,
                                  child: const Text('Login')),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: OneHubTheme.sectionGap),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('New here? ',
                              style: OneHubTextStyles.linkText(textSecondary)),
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const SignupScreen()),
                            ),
                            child: Text('Sign up',
                                style: OneHubTextStyles.linkText(primary)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
