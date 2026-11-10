import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import '../help/help_content.dart';
import 'profile_state.dart';
import '../requirements/my_requests_screen.dart';

// Customer Profile, reached from the Profile item in the dashboard's nav bar.
// Matches the other redesigned screens (PageGlow, page title in the AppBar, one GlowCard, bordered tile) — no new reference, applied
// on request.
//
// The name, phone and email come from GET /users/me (see profile_state.dart),
// reloaded each time the screen opens and on pull to refresh. Edit profile
// saves through PATCH /users/me. "My requests" and "Log out" are real;
// logging out clears the stored token and the loaded profile, and returns to
// the login screen with no way back.

class ProfileScreen extends StatefulWidget {
  /// True when shown as the Profile tab under the bottom bar: no back arrow.
  final bool asTab;
  const ProfileScreen({super.key, this.asTab = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      await loadCustomerProfile();
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _confirmLogout() async {
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
    if (confirmed != true || !mounted) return;
    await api.logout();
    customerProfile.value = null;
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<ProfileDetails?>(
        valueListenable: customerProfile,
        builder: _buildWith,
      );

  Widget _buildWith(BuildContext context, ProfileDetails? d, Widget? _) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;

    return Scaffold(
      appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: widget.asTab
              ? null
              : BackButton(onPressed: () => Navigator.of(context).pop()),
          titleSpacing: widget.asTab ? OneHubTheme.pageMargin : null,
          title: const Text('Profile')),
      body: PageGlow(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              // Pull to refresh works even when everything fits on screen.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                  horizontal: OneHubTheme.pageMargin, vertical: 8),
              children: [
                Text('Your account on OneHub.',
                    style: OneHubTextStyles.bodyText(textSecondary)),
                const SizedBox(height: OneHubTheme.sectionGap),
                _AccountCard(
                    details: d,
                    // Keeps showing what is already loaded while it refreshes.
                    loading: _loading && d == null,
                    failed: _failed && d == null),
                const SizedBox(height: 26),
                Text('Account',
                    style: OneHubTextStyles.pageHeading(textPrimary)
                        .copyWith(fontSize: 18)),
                const SizedBox(height: 12),
                OneHubLinkTile(
                  icon: OneHubIcons.user,
                  title: 'Edit profile',
                  subtitle: 'Name and email',
                  onTap: () {
                    if (d == null) return;
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => EditProfileScreen(
                              initial: d,
                              note: '',
                              onSave: saveCustomerProfile,
                            )));
                  },
                ),
                const SizedBox(height: 12),
                OneHubLinkTile(
                  icon: OneHubIcons.notification,
                  title: 'Settings',
                  subtitle: 'Notifications and about',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SettingsScreen(
                          appName: 'OneHub',
                          toggles: customerSettingsToggles))),
                ),
                const SizedBox(height: 12),
                OneHubLinkTile(
                  icon: OneHubIcons.confirmed,
                  title: 'Help & support',
                  subtitle: 'FAQs and contact',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const HelpScreen(
                          faqs: customerFaqs,
                          supportEmail: customerSupportEmail,
                          supportPhone: customerSupportPhone))),
                ),
                const SizedBox(height: 12),
                OneHubLinkTile(
                  icon: OneHubIcons.lock,
                  title: 'Terms & privacy',
                  subtitle: 'How OneHub works and handles your data',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const InfoScreen(
                              title: 'Terms & privacy',
                              subtitle: 'The ground rules.',
                              notice: legalPlaceholderNotice,
                              sections: [
                                ...onehubTermsSections,
                                ...onehubPrivacySections
                              ]))),
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
                    MaterialPageRoute(
                        builder: (_) => const MyRequestsScreen()),
                  ),
                ),
                const SizedBox(height: 32),
                OutlinedButton(
                  onPressed: _confirmLogout,
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
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final ProfileDetails? details;
  final bool loading;
  final bool failed;
  const _AccountCard(
      {required this.details, required this.loading, required this.failed});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
    final d = details;

    if (d == null) {
      return GlowCard(
        child: Padding(
          padding: const EdgeInsets.all(OneHubTheme.cardPadding),
          child: failed
              ? Text('Could not load your profile. Pull down to retry.',
                  style: TextStyle(color: context.statusDanger))
              : const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final name = d.name.isEmpty ? 'Customer' : d.name;
    return GlowCard(
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
                name.substring(0, 1).toUpperCase(),
                style: OneHubTextStyles.pageHeading(Colors.white)
                    .copyWith(fontSize: 24),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OneHubTextStyles.pageHeading(textPrimary)
                          .copyWith(fontSize: 20)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(OneHubIcons.phone, size: 14, color: textMuted),
                      const SizedBox(width: 6),
                      Text(d.phone,
                          style: OneHubTextStyles.bodyText(textSecondary)),
                    ],
                  ),
                  if (d.email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(OneHubIcons.email, size: 14, color: textMuted),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            d.email,
                            overflow: TextOverflow.ellipsis,
                            style: OneHubTextStyles.bodyText(textSecondary),
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
    );
  }
}
