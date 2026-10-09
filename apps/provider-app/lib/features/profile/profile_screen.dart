import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import '../requirements/active_jobs_screen.dart';

// Provider Profile, reached from the Profile item in the dashboard's nav bar.
// Mirrors the customer profile (PageGlow, back-only AppBar plus in-body
// heading, one GlowCard, bordered tiles) — no new reference, applied on
// request — plus a card of business details.
//
// Every detail shown is explicit dummy data: there is no profile endpoint to
// read them from yet. Replace the `_dummy*` constants when one exists.
// "Active jobs" and "Log out" are real; logging out clears the stored token
// and returns to the login screen with no way back.
const _dummyName = 'Asha Electricals';
const _dummyPhone = '+91 98765 12345';
const _dummyEmail = 'asha@example.com';
const _dummyCategory = 'Electrician';
const _dummyCoverage = '5 km radius';
const _dummyExperience = '8 years';

/// Takes an optional [client], like the other provider screens, so tests can
/// use a fake API.
class ProfileScreen extends StatelessWidget {
  final ApiClient? client;
  const ProfileScreen({super.key, this.client});

  Future<void> _confirmLogout(BuildContext context) async {
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
    if (confirmed != true || !context.mounted) return;
    await (client ?? api).logout();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
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
    final iconFill =
        dark ? OneHubColors.cardFillDark : OneHubColors.cardFillLight;
    final iconBorder =
        dark ? OneHubColors.cardBorderDark : OneHubColors.cardBorderLight;

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
              Text('Your provider account.',
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
                          _dummyName.substring(0, 1),
                          style: OneHubTextStyles.pageHeading(Colors.white)
                              .copyWith(fontSize: 24),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_dummyName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: OneHubTextStyles.pageHeading(textPrimary)
                                    .copyWith(fontSize: 20)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(OneHubIcons.phone,
                                    size: 14, color: textMuted),
                                const SizedBox(width: 6),
                                Text(_dummyPhone,
                                    style: OneHubTextStyles.bodyText(
                                        textSecondary)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(OneHubIcons.email,
                                    size: 14, color: textMuted),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _dummyEmail,
                                    overflow: TextOverflow.ellipsis,
                                    style: OneHubTextStyles.bodyText(
                                        textSecondary),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TintedBadge(
                                label: 'VERIFIED',
                                color: context.statusSuccess,
                                pill: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Text('Business',
                  style: OneHubTextStyles.pageHeading(textPrimary)
                      .copyWith(fontSize: 18)),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    children: [
                      const _DetailRow(
                          icon: OneHubIcons.category,
                          label: 'SERVICE CATEGORY',
                          value: _dummyCategory),
                      Divider(height: 1, color: iconBorder),
                      const _DetailRow(
                          icon: OneHubIcons.location,
                          label: 'COVERAGE',
                          value: _dummyCoverage),
                      Divider(height: 1, color: iconBorder),
                      const _DetailRow(
                          icon: OneHubIcons.calendar,
                          label: 'EXPERIENCE',
                          value: _dummyExperience),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Text('Activity',
                  style: OneHubTextStyles.pageHeading(textPrimary)
                      .copyWith(fontSize: 18)),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => ActiveJobsScreen(client: client)),
                  ),
                  borderRadius:
                      BorderRadius.circular(OneHubTheme.radiusFormCard),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: iconFill,
                            border: Border.all(color: iconBorder),
                          ),
                          child: Icon(OneHubIcons.documentList,
                              color: textPrimary, size: 18),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Active jobs',
                                  style: OneHubTextStyles.bodyText(textPrimary)
                                      .copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15)),
                              const SizedBox(height: 2),
                              Text('Track and finish your jobs',
                                  style: OneHubTextStyles.fieldLabel(textMuted)
                                      .copyWith(
                                          letterSpacing: 0, fontSize: 11)),
                            ],
                          ),
                        ),
                        Icon(OneHubIcons.chevronRight,
                            size: 18, color: textMuted),
                      ],
                    ),
                  ),
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
