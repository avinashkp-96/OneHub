import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import '../availability/availability_screen.dart';
import '../business/business_details.dart';
import '../business/business_details_screen.dart';
import '../plans/plans_screen.dart';
import '../ratings/ratings_screen.dart';
import '../help/help_content.dart';
import 'payout_documents_screen.dart';
import 'profile_state.dart';
import '../requirements/active_jobs_screen.dart';

// Provider Profile, reached from the Profile item in the dashboard's nav bar.
// Mirrors the customer profile (PageGlow, page title in the AppBar, one
// GlowCard, bordered tiles) plus a card of business details.
//
// Everything on the account and Business cards comes from one
// GET /providers/me (docx 5.2): business name, phone, email, photo, verification
// state, category, services, coverage and experience. Edit profile, Business
// details and Payout & documents all save through the API and reload it.
// "Active jobs" and "Log out" are real; logging out clears the stored token
// and returns to the login screen with no way back.

/// Takes an optional [client], like the other provider screens, so tests can
/// use a fake API.
class ProfileScreen extends StatefulWidget {
  final ApiClient? client;

  /// True when shown as the Profile tab under the bottom bar: no back arrow.
  final bool asTab;
  const ProfileScreen({super.key, this.client, this.asTab = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ApiClient get _api => widget.client ?? api;

  BusinessDetails? _details;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final json = await _api.get('/providers/me') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _details = BusinessDetails.fromJson(json);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _details = null;
        _loading = false;
      });
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content:
            const Text('You will need to log in again to receive requests.'),
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
    await _api.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  Future<void> _openThenReload(Widget screen) async {
    final saved = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => screen));
    if (saved == true && mounted) _load();
  }

  Future<void> _editProfile(BusinessDetails d) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditProfileScreen(
        initial: ProfileDetails(
            name: d.businessName, phone: d.phoneLabel, email: d.email),
        nameLabel: 'BUSINESS NAME',
        note: '',
        onSave: (name, email) async {
          if (name != d.businessName) {
            await _api.patch('/providers/me', {'businessName': name},
                auth: true);
          }
          if (email != d.email) {
            await _api.patch(
                '/users/me', {'email': email.isEmpty ? null : email},
                auth: true);
          }
        },
      ),
    ));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
    final d = _details;
    final client = widget.client;

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
                Text('Your provider account.',
                    style: OneHubTextStyles.bodyText(textSecondary)),
                const SizedBox(height: OneHubTheme.sectionGap),
                _AccountCard(details: d, loading: _loading),
                const SizedBox(height: 26),
                _BusinessCard(
                  details: d,
                  loading: _loading,
                  onEdit: () =>
                      _openThenReload(BusinessDetailsScreen(client: client)),
                ),
                const SizedBox(height: 26),
                Text('Account',
                    style: OneHubTextStyles.pageHeading(textPrimary)
                        .copyWith(fontSize: 18)),
                const SizedBox(height: 12),
                OneHubLinkTile(
                  icon: OneHubIcons.user,
                  title: 'Edit profile',
                  subtitle: 'Business name and email',
                  onTap: () {
                    if (d != null) _editProfile(d);
                  },
                ),
                const SizedBox(height: 12),
                OneHubLinkTile(
                  icon: OneHubIcons.documentList,
                  title: 'Payout & documents',
                  subtitle: 'Photo, ID proof and bank or UPI details',
                  onTap: () {
                    if (d != null) {
                      _openThenReload(
                          PayoutDocumentsScreen(details: d, client: client));
                    }
                  },
                ),
                const SizedBox(height: 12),
                OneHubLinkTile(
                  icon: OneHubIcons.wallet,
                  title: 'Plans',
                  subtitle: 'Pay per unlock or go monthly',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => PlansScreen(client: client))),
                ),
                const SizedBox(height: 12),
                OneHubLinkTile(
                  icon: OneHubIcons.notification,
                  title: 'Settings',
                  subtitle: 'Notifications and about',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SettingsScreen(
                          appName: 'OneHub Provider',
                          toggles: providerSettingsToggles))),
                ),
                const SizedBox(height: 12),
                OneHubLinkTile(
                  icon: OneHubIcons.confirmed,
                  title: 'Help & support',
                  subtitle: 'FAQs and contact',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const HelpScreen(
                          faqs: providerFaqs,
                          supportEmail: providerSupportEmail,
                          supportPhone: providerSupportPhone))),
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
                  icon: OneHubIcons.calendar,
                  title: 'Availability',
                  subtitle: 'Working hours and days',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const AvailabilityScreen())),
                ),
                const SizedBox(height: 12),
                OneHubLinkTile(
                  icon: OneHubIcons.starOutline,
                  title: 'Ratings',
                  subtitle: 'What customers say about your work',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => RatingsScreen(client: client))),
                ),
                const SizedBox(height: 12),
                OneHubLinkTile(
                  icon: OneHubIcons.documentList,
                  title: 'Active jobs',
                  subtitle: 'Track and finish your jobs',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => ActiveJobsScreen(client: client)),
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

/// Avatar (the photo link when there is one, else the initial), business
/// name, phone and email, and a verification badge: ID UNDER REVIEW while a
/// new ID proof waits, VERIFIED when active, PENDING otherwise.
class _AccountCard extends StatelessWidget {
  final BusinessDetails? details;
  final bool loading;
  const _AccountCard({required this.details, required this.loading});

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

    if (loading || d == null) {
      return GlowCard(
        child: Padding(
          padding: const EdgeInsets.all(OneHubTheme.cardPadding),
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : Text('Could not load your profile. Pull down to retry.',
                  style: TextStyle(color: context.statusDanger)),
        ),
      );
    }

    final (badge, badgeColor) = d.idProofNeedsReview
        ? ('ID UNDER REVIEW', context.statusWarning)
        : d.status == 'ACTIVE'
            ? ('VERIFIED', context.statusSuccess)
            : ('PENDING', context.statusWarning);
    final name = d.businessName.isEmpty ? 'Provider' : d.businessName;
    final photo = d.profilePhotoUrl;

    return GlowCard(
      child: Padding(
        padding: const EdgeInsets.all(OneHubTheme.cardPadding),
        child: Row(
          children: [
            Container(
              key: const Key('profile-avatar'),
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    OneHubColors.primary,
                    OneHubColors.primaryGradientEnd
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                image: photo == null
                    ? null
                    : DecorationImage(
                        image: NetworkImage(photo),
                        fit: BoxFit.cover,
                        onError: (_, __) {}),
              ),
              child: photo == null
                  ? Text(name.substring(0, 1).toUpperCase(),
                      style: OneHubTextStyles.pageHeading(Colors.white)
                          .copyWith(fontSize: 24))
                  : null,
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
                      Text(d.phoneLabel,
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
                          child: Text(d.email,
                              overflow: TextOverflow.ellipsis,
                              style: OneHubTextStyles.bodyText(textSecondary)),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  TintedBadge(label: badge, color: badgeColor, pill: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Business section: heading with an Edit button, then category,
/// services, coverage and experience.
class _BusinessCard extends StatelessWidget {
  final BusinessDetails? details;
  final bool loading;
  final VoidCallback onEdit;
  const _BusinessCard(
      {required this.details, required this.loading, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final divider =
        dark ? OneHubColors.cardBorderDark : OneHubColors.cardBorderLight;
    final d = details;

    final Widget body;
    if (loading) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (d == null) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text('Could not load your business details.',
            style: TextStyle(color: context.statusDanger)),
      );
    } else {
      body = Column(
        children: [
          _DetailRow(
              icon: OneHubIcons.category,
              label: 'SERVICE CATEGORY',
              value: d.categoryName ?? 'Not set'),
          Divider(height: 1, color: divider),
          _DetailRow(
              icon: OneHubIcons.work,
              label: 'SERVICES',
              value: d.servicesLabel),
          Divider(height: 1, color: divider),
          _DetailRow(
              icon: OneHubIcons.location,
              label: 'COVERAGE',
              value: d.coverageLabel),
          Divider(height: 1, color: divider),
          _DetailRow(
              icon: OneHubIcons.calendar,
              label: 'EXPERIENCE',
              value: d.experienceLabel),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Business',
                  style: OneHubTextStyles.pageHeading(textPrimary)
                      .copyWith(fontSize: 18)),
            ),
            TextButton.icon(
              onPressed: loading || d == null ? null : onEdit,
              icon: const Icon(OneHubIcons.edit, size: 16),
              label: const Text('Edit'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: body,
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textMuted),
          const SizedBox(width: 12),
          Expanded(
              child:
                  Text(label, style: OneHubTextStyles.fieldLabel(textMuted))),
          Text(value,
              style: OneHubTextStyles.bodyText(textPrimary)
                  .copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
