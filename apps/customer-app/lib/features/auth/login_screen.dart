import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import '../../core/widgets/field_label.dart';
import 'signup_screen.dart';

// docx 2.2 — Customer Login. Sign-up (2.1) and Forgot Password (2.5) live in
// signup_screen.dart and onehub_shared's ResetPasswordScreen respectively.
// Visual language matches the style guide PDF exactly (see OneHubColors/
// OneHubTheme/OneHubTextStyles): a translucent bordered card over the glow
// background, icon-next-to-label fields, a password show/hide toggle, a
// gradient rounded-rect CTA. That PDF documents the signup screen
// specifically, not login — this screen reuses the same type scale/tokens
// for consistency, since it's the same design system, but isn't itself
// pixel-specified anywhere.
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
                      Text('Welcome Back',
                          textAlign: TextAlign.center,
                          style: OneHubTextStyles.pageHeading(textPrimary)),
                      const SizedBox(height: 8),
                      Text(
                        'Log in to find and book local service providers',
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
                                  child: Text(_error!,
                                      style: TextStyle(
                                          color: context.statusDanger)),
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
                          Text("New here? ",
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
