import 'package:flutter/material.dart';
import '../theme/glow_card.dart';
import '../theme/onehub_colors.dart';
import '../theme/onehub_icons.dart';
import '../theme/onehub_theme.dart';

/// The account details both apps show on their Profile screen. Each app keeps
/// its own `ValueNotifier<ProfileDetails>` seeded with dummy values, since
/// there is no profile endpoint yet; edits live in memory until restart.
class ProfileDetails {
  final String name;
  final String phone;
  final String email;
  const ProfileDetails(
      {required this.name, required this.phone, required this.email});

  ProfileDetails copyWith({String? name, String? email}) => ProfileDetails(
      name: name ?? this.name, phone: phone, email: email ?? this.email);
}

/// Edit name and email. The phone number is shown but locked: changing it
/// would need a fresh OTP, which has no flow yet. Identical for the customer
/// and provider apps, so it lives here; [onSave] receives the trimmed values
/// and the app stores them. Same shell as the other screens (PageGlow,
/// back-only AppBar, in-body heading, one GlowCard).
class EditProfileScreen extends StatefulWidget {
  final ProfileDetails initial;
  final String nameLabel;
  final void Function(String name, String email) onSave;
  const EditProfileScreen({
    super.key,
    required this.initial,
    required this.onSave,
    this.nameLabel = 'FULL NAME',
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final _name = TextEditingController(text: widget.initial.name);
  late final _email = TextEditingController(text: widget.initial.email);
  late final _phone = TextEditingController(text: widget.initial.phone);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name.');
      return;
    }
    if (email.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    widget.onSave(name, email);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(const SnackBar(content: Text('Profile updated.')));
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;

    return Scaffold(
      appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.of(context).pop())),
      body: PageGlow(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(
                horizontal: OneHubTheme.pageMargin, vertical: 8),
            children: [
              Text('Edit profile',
                  style: OneHubTextStyles.pageHeading(textPrimary)
                      .copyWith(fontSize: 26)),
              const SizedBox(height: 8),
              Text('Keep your details up to date.',
                  style: OneHubTextStyles.bodyText(textSecondary)),
              const SizedBox(height: OneHubTheme.sectionGap),
              GlowCard(
                child: Padding(
                  padding: const EdgeInsets.all(OneHubTheme.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(_error!,
                              style: TextStyle(color: context.statusDanger)),
                        ),
                      _Label(widget.nameLabel, OneHubIcons.user),
                      const SizedBox(height: OneHubTheme.gapFieldInternals),
                      TextField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words),
                      const SizedBox(height: OneHubTheme.sectionGap),
                      const _Label('MOBILE NUMBER', OneHubIcons.phone),
                      const SizedBox(height: OneHubTheme.gapFieldInternals),
                      TextField(controller: _phone, enabled: false),
                      const SizedBox(height: 6),
                      Text(
                          'Changing your number needs a new OTP, which is not available yet.',
                          style: OneHubTextStyles.fieldLabel(textMuted)
                              .copyWith(letterSpacing: 0, fontSize: 11)),
                      const SizedBox(height: OneHubTheme.sectionGap),
                      const _Label('EMAIL ID', OneHubIcons.email),
                      const SizedBox(height: OneHubTheme.gapFieldInternals),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration:
                            const InputDecoration(hintText: 'you@example.com'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              PrimaryCta(onPressed: _save, child: const Text('Save changes')),
              const SizedBox(height: 12),
              Text('Saved on this device only for now.',
                  textAlign: TextAlign.center,
                  style: OneHubTextStyles.fieldLabel(textMuted)
                      .copyWith(letterSpacing: 0, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

// Same label as the other forms; private here because the apps' FieldLabel
// can't be imported into the shared package (see the reset password screen).
class _Label extends StatelessWidget {
  final String text;
  final IconData icon;
  const _Label(this.text, this.icon);

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
