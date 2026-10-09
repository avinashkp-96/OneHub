import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import 'profile_state.dart';
import '../requirements/my_requests_screen.dart';

// Customer Profile, reached from the Profile item in the dashboard's nav bar.
// Matches the other redesigned screens (PageGlow, back-only AppBar plus
// in-body heading, one GlowCard, bordered tile) — no new reference, applied
// on request.
//
// The name, phone and email are explicit dummy data: there is no profile
// endpoint to read them from yet, so they mirror the dummy "Meera" the
// dashboard already greets (see profile_state.dart; Edit profile changes them
// in memory only).
// "My requests" and "Log out" are real; logging out clears the stored token
// and returns to the login screen with no way back.

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
            'You will need to log in again to post or track requests.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
                foregroundColor: dialogContext.statusDanger),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await api.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ProfileDetails>(
        valueListenable: customerProfile,
        builder: _buildWith,
      );

  Widget _buildWith(BuildContext context, ProfileDetails d, Widget? _) {
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
              Text('Profile',
                  style: OneHubTextStyles.pageHeading(textPrimary)
                      .copyWith(fontSize: 26)),
              const SizedBox(height: 8),
              Text('Your account on OneHub.',
                  style: OneHubTextStyles.bodyText(textSecondary)),
              const SizedBox(height: OneHubTheme.sectionGap),
              GlowCard(
                child: Padding(
                  padding: const EdgeInsets.all(OneHubTheme.cardPadding),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              OneHubColors.primary,
                              OneHubColors.primaryGradientEnd
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Text(
                          d.name.substring(0, 1),
                          style: OneHubTextStyles.pageHeading(Colors.white)
                              .copyWith(fontSize: 24),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.name,
                                style: OneHubTextStyles.pageHeading(textPrimary)
                                    .copyWith(fontSize: 20)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(OneHubIcons.phone,
                                    size: 14, color: textMuted),
                                const SizedBox(width: 6),
                                Text(d.phone,
                                    style: OneHubTextStyles.bodyText(
                                        textSecondary)),
                              ],
                            ),
                            if (d.email.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(OneHubIcons.email,
                                      size: 14, color: textMuted),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      d.email,
                                      overflow: TextOverflow.ellipsis,
                                      style: OneHubTextStyles.bodyText(
                                          textSecondary),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Text('Account',
                  style: OneHubTextStyles.pageHeading(textPrimary)
                      .copyWith(fontSize: 18)),
              const SizedBox(height: 12),
              OneHubLinkTile(
                icon: OneHubIcons.user,
                title: 'Edit profile',
                subtitle: 'Name and email',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => EditProfileScreen(
                          initial: customerProfile.value,
                          onSave: (name, email) => customerProfile.value =
                              customerProfile.value
                                  .copyWith(name: name, email: email),
                        ))),
              ),
              const SizedBox(height: 12),
              OneHubLinkTile(
                icon: OneHubIcons.notification,
                title: 'Settings',
                subtitle: 'Notifications and about',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SettingsScreen(
                        appName: 'OneHub', toggles: customerSettingsToggles))),
              ),
              const SizedBox(height: 26),
              Text('Activity',
                  style: OneHubTextStyles.pageHeading(textPrimary)
                      .copyWith(fontSize: 18)),
              const SizedBox(height: 12),
              OneHubLinkTile(
                icon: OneHubIcons.documentList,
                title: 'My requests',
                subtitle: 'Track and review your jobs',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MyRequestsScreen()),
                ),
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () => _confirmLogout(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.statusDanger,
                  side: BorderSide(
                      color: context.statusDanger.withValues(alpha: 0.5)),
                ),
                child: const Text('Log out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
